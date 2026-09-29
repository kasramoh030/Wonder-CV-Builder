#!/usr/bin/env bash
#
# Inspects a release APK (and optionally the AAB) the way a store reviewer and
# a paranoid maintainer would: identity, version, permissions, exported
# components, debuggability, signing certificate, native ABIs, and a scan for
# anything that looks like a secret that should never have been compiled in.
#
# Exits non-zero on any finding that would block a release.
#
# Usage: tools/verify_release_artifact.sh [--allow-debug-signature] <apk> [aab]
#
# --allow-debug-signature  use on the per-push debug smoke build, where the
#                          debug key is expected; the signature is then
#                          reported as INFO instead of failing.
#
# Requires the Android SDK build-tools (aapt2, apksigner) and a JDK
# (jarsigner, keytool). Both are present on GitHub's ubuntu runners; locally,
# set ANDROID_HOME or ANDROID_SDK_ROOT.

set -uo pipefail

allow_debug_signature=0
if [ "${1:-}" = "--allow-debug-signature" ]; then
  allow_debug_signature=1
  shift
fi

APK="${1:-}"
AAB="${2:-}"

# "/dev/null" is the AAB-only invocation: a smoke build on a runner that
# has no signing key still has an app bundle worth inspecting.
if [ "$APK" = "/dev/null" ] || [ ! -e "$APK" ]; then
  if [ -n "$AAB" ] && [ -e "$AAB" ]; then
    APK=""
  fi
fi

if [ -z "$APK" ] && [ -z "$AAB" ]; then
  echo "usage: $0 [--allow-debug-signature] <release.apk> [release.aab]" >&2
  exit 2
fi
if [ -n "$APK" ] && [ ! -f "$APK" ]; then
  echo "error: no such APK: $APK" >&2
  exit 2
fi
if [ -n "$AAB" ] && [ ! -f "$AAB" ]; then
  echo "error: no such AAB: $AAB" >&2
  exit 2
fi

failures=0
report() { printf '%-34s | %-6s | %s\n' "$1" "$2" "$3"; }
pass()   { report "$1" "PASS" "$2"; }
fail()   { report "$1" "FAIL" "$2"; failures=$((failures + 1)); }
info()   { report "$1" "INFO" "$2"; }

# ── Locate the SDK tools ─────────────────────────────────────────────────────
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$SDK" ] || [ ! -d "$SDK" ]; then
  echo "ANDROID_HOME/ANDROID_SDK_ROOT is not set to an existing SDK." >&2
  exit 2
fi

build_tools_dir="$(find "$SDK/build-tools" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -1)"
AAPT2="${build_tools_dir}/aapt2"
APKSIGNER="${build_tools_dir}/apksigner"
for tool in "$AAPT2" "$APKSIGNER"; do
  if [ ! -x "$tool" ]; then
    echo "Missing SDK tool: $tool" >&2
    exit 2
  fi
done

if [ -n "$APK" ]; then
  # Indented as a block only in this guard; the body keeps its own
  # shape so the report stays one table.
  echo "Verifying $APK"
  echo "----------------------------------------------------------------------"

  # ── Identity ─────────────────────────────────────────────────────────────────
  badging="$("$AAPT2" dump badging "$APK" 2>/dev/null)"

  pkg="$(printf '%s\n' "$badging" | sed -n "s/^package: name='\([^']*\)'.*/\1/p")"
  version_code="$(printf '%s\n' "$badging" | sed -n "s/.*versionCode='\([^']*\)'.*/\1/p")"
  version_name="$(printf '%s\n' "$badging" | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")"
  label="$(printf '%s\n' "$badging" | sed -n "s/^application-label:'\(.*\)'/\1/p")"
  sdk_min="$(printf '%s\n' "$badging" | sed -n "s/^\(sdkVersion\|minSdkVersion\):'\([^']*\)'/\2/p" | head -1)"
  sdk_target="$(printf '%s\n' "$badging" | sed -n "s/^targetSdkVersion:'\([^']*\)'/\1/p")"

  if [ "$pkg" = "dev.cvpro.builder" ]; then
    pass "package name" "$pkg"
  else
    fail "package name" "expected dev.cvpro.builder, found '${pkg:-<none>}'"
  fi

  if [ -n "$version_code" ] && [ -n "$version_name" ]; then
    pass "version" "versionName=$version_name versionCode=$version_code"
  else
    fail "version" "could not read versionCode/versionName"
  fi

  info "launcher label" "${label:-<none>}"
  info "sdk range" "min=$sdk_min target=$sdk_target"

  # A store build must target a recent API. This is a floor, not a policy
  # statement: check the current Play requirement before each release.
  if [ -n "$sdk_target" ] && [ "$sdk_target" -ge 35 ]; then
    pass "target sdk" "targetSdk=$sdk_target (Play requires a current target)"
  else
    fail "target sdk" "targetSdk=${sdk_target:-unknown}; check the current Play requirement"
  fi

  # ── Debuggability and debug-only settings ────────────────────────────────────
  if printf '%s\n' "$badging" | grep -q '^application-debuggable'; then
    if [ "$allow_debug_signature" = "1" ]; then
      info "debuggable" "debug build (expected for the smoke APK)"
    else
      fail "debuggable" "release APK is marked android:debuggable"
    fi
  else
    pass "debuggable" "not debuggable"
  fi

  # ── Permissions ──────────────────────────────────────────────────────────────
  permissions="$(printf '%s\n' "$badging" | sed -n "s/^uses-permission: name='\([^']*\)'.*/\1/p" | sort -u)"
  permission_count="$(printf '%s\n' "$permissions" | grep -c . || true)"
  # androidx.core declares a signature-level permission to protect the app's own
  # dynamically registered receivers. It grants nothing to anyone else and is
  # added by the library, not by this app; INTERNET is the only permission the
  # app itself asks for.
  allowed_extra="${pkg}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"
  unexpected="$(printf '%s\n' "$permissions" | grep -v '^android.permission.INTERNET$' | grep -v "^${allowed_extra}$" | grep . || true)"
  if [ -z "$unexpected" ]; then
    pass "permissions" "INTERNET only (plus ${allowed_extra} from androidx.core)"
  else
    fail "permissions" "unexpected permission set: $(printf '%s' "$unexpected" | tr '\n' ' ')"
  fi
  info "permission count" "$permission_count"

  # ── Exported components ──────────────────────────────────────────────────────
  manifest_tree="$("$AAPT2" dump xmltree --file AndroidManifest.xml "$APK" 2>/dev/null)"
  # Walk the manifest dump and print the name of every exported component, so a
  # surprise is named rather than counted. aapt2 renders a boolean true either as
  # `=true` or as `(type 0x12)0xffffffff` depending on the build-tools version, so
  # both are accepted; a component with no readable name is reported as unknown
  # rather than dropped, because a silently unparsed manifest is how a check
  # passes without checking anything.
  exported_names="$(printf '%s\n' "$manifest_tree" | python3 -c '
  import re, sys

  component = re.compile(r"^\s*E: (activity|activity-alias|service|receiver|provider)\b")
  attribute = re.compile(r"^\s*A: .*?:name\(0x[0-9a-f]+\)=\"([^\"]*)\"")
  marker = re.compile(r"^\s*A: .*?:exported\(0x[0-9a-f]+\)=(.*)$")

  kind = None
  name = None
  for line in sys.stdin:
      found = component.match(line)
      if found:
          kind, name = found.group(1), None
          continue
      if kind is None:
          continue
      found = attribute.match(line)
      if found and name is None:
          name = found.group(1)
          continue
      found = marker.match(line)
      if found:
          value = found.group(1).strip()
          if value == "true" or value.endswith("0xffffffff"):
              print(kind + " " + (name if name else "unparsed-name"))
          kind, name = None, None
  ' | sort -u)"
  info "exported components" "${exported_names:-<none found>}"
  # Two exported components are expected in a Flutter app:
  #  * the launcher activity, which is the app's only entry point;
  #  * androidx.profileinstaller.ProfileInstallReceiver, which the Flutter
  #    embedding ships to install a baseline profile at install time. It is
  #    protected by android.permission.DUMP, a signature/privileged permission
  #    no ordinary app can hold, and it carries no app data.
  allowed_pattern='MainActivity|ProfileInstallReceiver'
  allowed_exported="$(printf '%s\n' "$exported_names" | grep -E "$allowed_pattern" | grep . || true)"
  unexpected_exported="$(printf '%s\n' "$exported_names" | grep -vE "$allowed_pattern" | grep . || true)"
  if [ -z "$exported_names" ]; then
    fail "exported surface" "no exported component found at all — the manifest dump was not parsed"
  elif [ -z "$unexpected_exported" ] && [ -n "$allowed_exported" ]; then
    pass "exported surface" "only the launcher activity is exported"
  else
    fail "exported surface" "unexpected exported component(s): $(printf '%s' "$unexpected_exported" | tr '\n' ' ')"
  fi

  # ── Signing ──────────────────────────────────────────────────────────────────
  signer="$("$APKSIGNER" verify --print-certs "$APK" 2>&1)"
  if "$APKSIGNER" verify "$APK" >/dev/null 2>&1; then
    pass "signature" "verified"
  else
    fail "signature" "apksigner verify failed"
  fi

  cert_dn="$(printf '%s\n' "$signer" | sed -n 's/^Signer #1 certificate DN: \(.*\)$/\1/p' | head -1)"
  if [ -z "$cert_dn" ]; then
    # Older and newer apksigner builds differ in spacing and in which line
    # carries the subject; fall back to the certificate block.
    cert_dn="$(printf '%s\n' "$signer" | sed -n 's/^\s*Subject: \(.*\)$/\1/p' | head -1)"
  fi
  if [ -z "$cert_dn" ]; then
    cert_dn="$(printf '%s\n' "$signer" | grep -o 'CN=[^,]*' | head -1)"
  fi
  schemes="$(printf '%s\n' "$signer" | sed -n 's/^Verified using \(.*\) \(v[0-9]\).*$/\2/p' | tr '\n' ' ')"
  if [ -z "$cert_dn" ]; then
    fail "signing certificate" "no certificate reported"
  elif printf '%s' "$cert_dn" | grep -qi 'Android Debug'; then
    if [ "$allow_debug_signature" = "1" ]; then
      info "signing certificate" "debug key (expected for the smoke build; not publishable)"
    else
      fail "signing certificate" "signed with the DEBUG key ($cert_dn) — not publishable"
    fi
  else
    pass "signing certificate" "$cert_dn"
  fi
  info "signature schemes" "${schemes:-<none reported>}"

  # ── Native libraries ─────────────────────────────────────────────────────────
  abis="$(unzip -Z1 "$APK" 2>/dev/null | sed -n 's|^lib/\([^/]*\)/.*|\1|p' | sort -u | tr '\n' ' ')"
  if [ -n "$abis" ]; then
    abi_count="$(printf '%s' "$abis" | wc -w)"
    if [ "$abi_count" -gt 1 ] && [ "$allow_debug_signature" != "1" ]; then
      info "native libraries" "universal APK (${abis% }) — intended for Cafe Bazaar / Myket; Google Play gets the AAB"
    else
      info "native libraries" "ABIs present: ${abis}"
    fi
  else
    info "native libraries" "none (no ABI split needed)"
  fi

  dex_count="$(unzip -Z1 "$APK" 2>/dev/null | grep -c '\.dex$' || true)"
  info "dex files" "$dex_count"

  # ── Accidental secrets ───────────────────────────────────────────────────────
  # A heuristic: the patterns are the ones that actually appear in committed
  # keys. It is deliberately broad — a false positive costs one look, a false
  # negative costs the key.
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  unzip -qq -o "$APK" -d "$tmpdir" >/dev/null 2>&1 || true
  # Only files that can carry a key are scanned. Fonts and images are excluded
  # because their binary metadata contains strings like "…sk-ExtraBoldItalic…"
  # that match a key pattern without being one: a scan that cries wolf is a scan
  # nobody reads.
  while IFS= read -r candidate; do
    grep -Iq . "$candidate" 2>/dev/null || continue
    grep -hoaE '(sk-(proj-)?[A-Za-z0-9_-]{32,}|AIza[0-9A-Za-z_-]{35}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{60,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,})' "$candidate" 2>/dev/null
  done < <(find "$tmpdir" -type f \( -name '*.dex' -o -name '*.json' -o -name '*.xml' -o -name '*.txt' -o -name '*.properties' -o -name '*.yaml' -o -name '*.yml' -o -name '*.env' -o -name '*.so' \) ) > /tmp/secret_hits.txt 2>/dev/null || true
  secret_hits="$(sort -u /tmp/secret_hits.txt 2>/dev/null | head -5)"
  if [ -n "$secret_hits" ]; then
    fail "embedded secrets" "found: $(printf '%s' "$secret_hits" | tr '\n' ' ')"
  else
    pass "embedded secrets" "none of the known key shapes appear in the APK"
  fi

  # ── Network security ─────────────────────────────────────────────────────────
  if printf '%s\n' "$manifest_tree" | grep -q 'usesCleartextTraffic'; then
    if printf '%s\n' "$manifest_tree" | grep -q 'usesCleartextTraffic.*=true'; then
      fail "cleartext traffic" "android:usesCleartextTraffic is true"
    else
      pass "cleartext traffic" "explicitly disabled"
    fi
  else
    pass "cleartext traffic" "default for targetSdk>=28 (disabled)"
  fi

fi

# ── App bundle ───────────────────────────────────────────────────────────────
if [ -n "$AAB" ] && [ -f "$AAB" ]; then
  echo
  echo "Verifying $AAB"
  echo "----------------------------------------------------------------------"
  if unzip -Z1 "$AAB" 2>/dev/null | grep -q '^base/manifest/AndroidManifest.xml$'; then
    pass "bundle structure" "base/manifest present"
  else
    fail "bundle structure" "base/manifest/AndroidManifest.xml missing"
  fi
  if unzip -Z1 "$AAB" 2>/dev/null | grep -q '^base/dex/'; then
    pass "bundle dex" "$(unzip -Z1 "$AAB" | grep -c '^base/dex/') dex file(s)"
  else
    fail "bundle dex" "no base/dex entries"
  fi
  if jarsigner -verify "$AAB" >/dev/null 2>&1; then
    bundle_dn="$(jarsigner -verify -verbose -certs "$AAB" 2>/dev/null | sed -n 's/^.*CN=\([^,]*\).*/\1/p' | head -1)"
    if printf '%s' "$bundle_dn" | grep -qi 'Android Debug'; then
      if [ "$allow_debug_signature" = "1" ]; then
        info "bundle signature" "debug key (expected for the smoke build)"
      else
        fail "bundle signature" "signed with the DEBUG key"
      fi
    else
      pass "bundle signature" "verified (CN=${bundle_dn:-unknown})"
    fi
  else
    fail "bundle signature" "jarsigner -verify failed"
  fi
  info "bundle size" "$(du -h "$AAB" | cut -f1)"
fi

echo "----------------------------------------------------------------------"
if [ "$failures" -eq 0 ]; then
  echo "All release checks passed."
  exit 0
fi
echo "$failures check(s) failed."
exit 1
