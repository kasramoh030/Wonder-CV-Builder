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

if [ -z "$APK" ] || [ ! -f "$APK" ]; then
  echo "usage: $0 <release.apk> [release.aab]" >&2
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

echo "Verifying $APK"
echo "----------------------------------------------------------------------"

# ── Identity ─────────────────────────────────────────────────────────────────
badging="$("$AAPT2" dump badging "$APK" 2>/dev/null)"

pkg="$(printf '%s\n' "$badging" | sed -n "s/^package: name='\([^']*\)'.*/\1/p")"
version_code="$(printf '%s\n' "$badging" | sed -n "s/.*versionCode='\([^']*\)'.*/\1/p")"
version_name="$(printf '%s\n' "$badging" | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")"
label="$(printf '%s\n' "$badging" | sed -n "s/^application-label:'\(.*\)'/\1/p")"
sdk_min="$(printf '%s\n' "$badging" | sed -n "s/^sdkVersion:'\([^']*\)'/\1/p")"
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
  fail "debuggable" "release APK is marked android:debuggable"
else
  pass "debuggable" "not debuggable"
fi

# ── Permissions ──────────────────────────────────────────────────────────────
permissions="$(printf '%s\n' "$badging" | sed -n "s/^uses-permission: name='\([^']*\)'.*/\1/p" | sort -u)"
permission_count="$(printf '%s\n' "$permissions" | grep -c . || true)"
if [ "$permissions" = "android.permission.INTERNET" ]; then
  pass "permissions" "INTERNET only"
else
  fail "permissions" "unexpected permission set: $(printf '%s' "$permissions" | tr '\n' ' ')"
fi
info "permission count" "$permission_count"

# ── Exported components ──────────────────────────────────────────────────────
manifest_tree="$("$AAPT2" dump xmltree --file AndroidManifest.xml "$APK" 2>/dev/null)"
exported="$(printf '%s\n' "$manifest_tree" | grep -c 'android:exported(0x[0-9a-f]*)=true' || true)"
info "exported components" "$exported (expected: 1 — the launcher activity)"
if [ "$exported" -eq 1 ]; then
  pass "exported surface" "only the launcher activity is exported"
else
  fail "exported surface" "$exported exported components; review the manifest"
fi

# ── Signing ──────────────────────────────────────────────────────────────────
signer="$("$APKSIGNER" verify --print-certs "$APK" 2>&1)"
if "$APKSIGNER" verify "$APK" >/dev/null 2>&1; then
  pass "signature" "verified"
else
  fail "signature" "apksigner verify failed"
fi

cert_dn="$(printf '%s\n' "$signer" | sed -n 's/^Signer #1 certificate DN: \(.*\)$/\1/p' | head -1)"
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
  info "native libraries" "ABIs present: ${abis}"
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
secret_hits="$(grep -rhoaE '(sk-[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{30,}|ghp_[A-Za-z0-9]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16})' "$tmpdir" 2>/dev/null | sort -u | head -5)"
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
