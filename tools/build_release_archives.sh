#!/usr/bin/env bash
#
# Builds the two handover archives from a commit:
#
#   deliverables/Wonder-CV-Builder-v1.0.0-FINAL.zip      complete source
#   deliverables/Wonder-CV-Builder-Android-v1.0.0.zip    the Android project
#
#   tools/build_release_archives.sh [--ref <commit>]
#
# Both come from `git archive`, so they contain exactly the files that are
# tracked at that commit — no build output, no local editor state, and nothing
# that .gitignore keeps out of the repository in the first place. That last
# property is the reason for using git rather than zipping the working tree: a
# keystore is ignored, so a keystore cannot be in here.
#
# Every archive is then opened again and checked, not assumed:
#
#   * it lists and tests clean (a truncated zip that looks like a file is worse
#     than no file);
#   * the files a build needs are actually present;
#   * none of the names that carry secrets are present;
#   * tools/check_no_key_material.sh --dir passes over the unpacked contents.
#
# The owner's keystore package is built separately, by
# tools/create_owner_package.sh, and is never merged into these.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

REF="HEAD"
OUT_DIR="$REPO_ROOT/deliverables"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
hr()    { printf '%.0s─' {1..72}; printf '\n'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --ref) REF="${2:-}"; shift 2 ;;
    -h|--help) sed -n '3,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

for tool in git zip unzip tar; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool is not on PATH."
done

COMMIT="$(git rev-parse "$REF")" || die "cannot resolve $REF"
SHORT="$(git rev-parse --short "$COMMIT")"
VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -1)"
VERSION_NAME="${VERSION%%+*}"
VERSION_CODE="${VERSION#*+}"
[ -n "$VERSION_NAME" ] || die "could not read version from pubspec.yaml"

FINAL_NAME="Wonder-CV-Builder-v$VERSION_NAME-FINAL.zip"
ANDROID_NAME="Wonder-CV-Builder-Android-v$VERSION_NAME.zip"
FINAL_PREFIX="Wonder-CV-Builder-v$VERSION_NAME-FINAL"
ANDROID_PREFIX="Wonder-CV-Builder-Android-v$VERSION_NAME"
TODAY="$(date -u '+%Y-%m-%d')"

if ! git diff --quiet || ! git diff --cached --quiet; then
  warn "the working tree has uncommitted changes; these archives are built from"
  warn "$SHORT, so they contain the committed state, not what is on disk right now."
fi

# ── The note that goes inside each archive ───────────────────────────────────
#
# Written into the archive rather than committed, because it describes the
# delivery rather than the project.

delivery_readme() {
  cat <<EOF
WONDER CV BUILDER — SOURCE DELIVERY
=====================================================================
Version:            $VERSION_NAME ($VERSION_CODE)
Built from commit:  $SHORT ($COMMIT)
Built on:           $TODAY

WHAT THIS IS
  The complete source of the app, as committed: Flutter application code,
  tests, Android project, bundled assets, localisation, fonts, regional rules,
  tools and documentation. Nothing here is generated output; a clean checkout
  plus the Flutter SDK is enough to rebuild it.

BUILD IT
  flutter --version          # 3.47.5 or newer, stable channel
  flutter pub get
  flutter analyze --fatal-warnings
  flutter test
  flutter build appbundle --release     # AAB for Google Play
  flutter build apk --release           # APK for Bazaar, Myket, sideloading

  A release build needs signing material, which is deliberately not here. See
  docs/RELEASE.md: the keystore is created by its owner, kept outside any
  repository, and supplied to CI through repository secrets. Without it the
  release workflow fails instead of falling back to the debug key.

WHAT IS NOT HERE, ON PURPOSE
  No keystore, no private key, no password, no API key, no .env, no
  credentials of any kind. tools/check_no_key_material.sh scans for all of
  them, and the build fails if any ever appear:

      bash tools/check_no_key_material.sh

WHAT ELSE TO READ
  README.md                 what the app does and how it is laid out
  docs/RELEASE.md           release procedure, signing, owner credentials
  docs/PRIVACY.md           what is stored, what leaves the device, and why
  docs/STORE_CHECKLIST.md   what still has to be done before publishing
  docs/QA.md                the test matrix and its current state
  docs/release-notes/       the release notes per version
EOF
}

android_build_notes() {
  cat <<EOF
ANDROID PROJECT — READ ME FIRST
=====================================================================
This is the android/ directory of Wonder CV Builder $VERSION_NAME ($VERSION_CODE),
built from commit $SHORT. It is a Flutter Android host project: the Dart code
that makes up the app lives in the parent project's lib/, and the two are
built together.

GRADLE WRAPPER
  gradlew, gradlew.bat and gradle/wrapper/gradle-wrapper.jar are NOT in this
  archive, because Flutter's own android/.gitignore keeps them out of the
  repository — they are regenerated by the Flutter tool from its own cached
  Gradle distribution on the first build. gradle/wrapper/gradle-wrapper.properties
  IS here, and it is what pins the Gradle version.

  Building from the parent project is therefore the supported path:

      flutter pub get
      flutter build appbundle --release

  If you need these files present up front — for an IDE, or a CI image that
  runs Gradle directly — regenerate the platform scaffolding with:

      flutter create --platforms=android .

  from the parent project root. That rewrites only the missing wrapper files.

SIGNING
  android/key.properties is git-ignored and is not in this archive, and neither
  is any keystore. The release build reads its credentials from Gradle
  properties or the environment; see docs/RELEASE.md. A release build without
  them fails rather than quietly signing with the debug key.

WHAT IS CONFIGURED HERE
  applicationId      dev.cvpro.builder
  versionName        $VERSION_NAME
  versionCode        $VERSION_CODE
  minSdk / targetSdk see app/build.gradle.kts (24 / 36)
  permissions        INTERNET only — the optional online analyser is the only
                     feature that uses the network, and everything else works
                     with the radio off.
  cleartext traffic  disabled
EOF
}

# ── Build ────────────────────────────────────────────────────────────────────

stage_root="$(mktemp -d)"
trap 'rm -rf "$stage_root"' EXIT

mkdir -p "$OUT_DIR"
built=()

# Zips the folder itself rather than its contents, so extracting the archive
# gives the owner one clean directory instead of scattering files next to
# whatever was already in the folder they extracted into.
build_archive() {
  local out="$1" root="$2" note_file="$3" note_text_fn="$4"
  local prefix; prefix="$(basename "$root")"

  rm -f "$out"
  "$note_text_fn" >"$root/$note_file"

  ( cd "$stage_root" && zip -r -X -q "$out" "$prefix" ) || die "zip failed for $out"
  built+=("$out")
}

bold "Building the source archives from $SHORT"

# Complete source.
final_root="$stage_root/$FINAL_PREFIX"
mkdir -p "$final_root"
git archive --format=tar "$COMMIT" | tar -x -C "$final_root" || die "git archive failed"
build_archive "$OUT_DIR/$FINAL_NAME" "$final_root" "DELIVERY-README.txt" delivery_readme

# The Android project alone, lifted to the top level of its own archive.
android_root="$stage_root/$ANDROID_PREFIX"
mkdir -p "$android_root" "$stage_root/_android_tmp"
git archive --format=tar "$COMMIT" android | tar -x -C "$stage_root/_android_tmp" || die "git archive failed"
( cd "$stage_root/_android_tmp" && tar -cf - android ) \
  | ( cd "$android_root" && tar -xf - --strip-components=1 ) || die "could not stage the Android project"
build_archive "$OUT_DIR/$ANDROID_NAME" "$android_root" "ANDROID-BUILD-NOTES.txt" android_build_notes

# ── Verify ───────────────────────────────────────────────────────────────────

# Names that must never appear inside a handed-over archive.
forbidden='(\.jks$|\.keystore$|\.p12$|\.pfx$|(^|/)key\.properties$|(^|/)\.env$|(^|/)\.env\.|\.pem$|(^|/)id_rsa|service-account.*\.json$|google-services\.json$|(^|/)secrets\.json$|(^|/)credentials\.json$)'

verify() {
  local out="$1" root="$2"
  shift 2
  local required=("$@")
  local name; name="$(basename "$out")"
  hr
  bold "Verifying $name"

  # 1. It is a zip, and it is not damaged.
  unzip -tq "$out" >/dev/null 2>&1 || die "$name is not a readable zip."
  local entries; entries="$(unzip -Z1 "$out" 2>/dev/null)"
  ok "opens and tests clean ($(printf '%s\n' "$entries" | wc -l | tr -d ' ') entries)"

  # 2. Everything a build needs is present.
  local missing=0
  for want in "${required[@]}"; do
    if ! printf '%s\n' "$entries" | grep -qx "$want"; then
      warn "missing from the archive: $want"
      missing=$((missing + 1))
    fi
  done
  [ "$missing" -eq 0 ] || die "$name is incomplete: $missing required file(s) missing."
  ok "every file needed to rebuild is present"

  # 3. Nothing that carries a secret is present, by name.
  local forbidden_hits
  forbidden_hits="$(printf '%s\n' "$entries" | grep -Ei "$forbidden" || true)"
  if [ -n "$forbidden_hits" ]; then
    printf '%s\n' "$forbidden_hits" | sed 's/^/      /' >&2
    die "$name contains a file that must never be published (listed above)."
  fi
  ok "no keystore, .env, key.properties or credential file by name"

  # 4. And nothing that carries one by content. The same scanner CI runs, over
  #    the unpacked archive, so the check is of what the owner will actually
  #    open rather than of what we believe went in.
  local unpack; unpack="$(mktemp -d)"
  unzip -qq "$out" -d "$unpack" || die "could not unpack $name for checking."
  if [ "$name" = "$ANDROID_NAME" ]; then
    # The Android archive is a subtree: scan it where it now sits.
    if ! bash "$REPO_ROOT/tools/check_no_key_material.sh" --dir "$unpack" >"$unpack/.scan.txt" 2>&1; then
      cat "$unpack/.scan.txt" >&2; rm -rf "$unpack"
      die "$name contains key material or a credential (reported above)."
    fi
  else
    if ! bash "$REPO_ROOT/tools/check_no_key_material.sh" --dir "$unpack" >"$unpack/.scan.txt" 2>&1; then
      cat "$unpack/.scan.txt" >&2; rm -rf "$unpack"
      die "$name contains key material or a credential (reported above)."
    fi
  fi
  rm -rf "$unpack"
  ok "no key material or credential in the contents (scanned, not assumed)"

  # 5. Say what it is, in bytes, and how to prove it arrived intact.
  printf '  %-14s %s bytes\n' "size:" "$(wc -c <"$out" | tr -d ' ')"
  printf '  %-14s %s\n' "sha256:" "$( (sha256sum "$out" 2>/dev/null || shasum -a 256 "$out") | cut -d' ' -f1)"
  printf '  %-14s %s\n' "root folder:" "$(printf '%s\n' "$entries" | sed 's|/.*||' | sort -u | head -1)"
}

verify "$OUT_DIR/$FINAL_NAME" "$final_root" \
  "$FINAL_PREFIX/pubspec.yaml" \
  "$FINAL_PREFIX/README.md" \
  "$FINAL_PREFIX/lib/main.dart" \
  "$FINAL_PREFIX/assets/data/regional_rules/germany.json" \
  "$FINAL_PREFIX/lib/features/export/library_backup_service.dart" \
  "$FINAL_PREFIX/analysis_options.yaml" \
  "$FINAL_PREFIX/.gitignore" \
  "$FINAL_PREFIX/android/settings.gradle.kts" \
  "$FINAL_PREFIX/android/gradle.properties" \
  "$FINAL_PREFIX/android/app/build.gradle.kts" \
  "$FINAL_PREFIX/android/app/src/main/AndroidManifest.xml" \
  "$FINAL_PREFIX/android/app/src/main/kotlin/dev/cvpro/builder/MainActivity.kt" \
  "$FINAL_PREFIX/docs/PRIVACY.md" \
  "$FINAL_PREFIX/docs/RELEASE.md" \
  "$FINAL_PREFIX/docs/STORE_CHECKLIST.md" \
  "$FINAL_PREFIX/DELIVERY-README.txt"

verify "$OUT_DIR/$ANDROID_NAME" "$android_root" \
  "$ANDROID_PREFIX/settings.gradle.kts" \
  "$ANDROID_PREFIX/build.gradle.kts" \
  "$ANDROID_PREFIX/gradle.properties" \
  "$ANDROID_PREFIX/gradle/wrapper/gradle-wrapper.properties" \
  "$ANDROID_PREFIX/app/build.gradle.kts" \
  "$ANDROID_PREFIX/app/proguard-rules.pro" \
  "$ANDROID_PREFIX/app/src/main/AndroidManifest.xml" \
  "$ANDROID_PREFIX/app/src/debug/AndroidManifest.xml" \
  "$ANDROID_PREFIX/app/src/main/kotlin/dev/cvpro/builder/MainActivity.kt" \
  "$ANDROID_PREFIX/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml" \
  "$ANDROID_PREFIX/ANDROID-BUILD-NOTES.txt"

# ── The rest of the handover ─────────────────────────────────────────────────
#
# The two documents a release is actually judged by, next to the archives they
# come from, and an index with the checksums that let the owner prove the files
# arrived intact. These are copies; the canonical files stay in docs/.

copy_with_provenance() {
  local source="$1" target="$2" title="$3"
  [ -f "$source" ] || { warn "not in this commit, so not copied: $source"; return; }
  {
    printf '<!-- Copy of %s from commit %s (%s). Edit the repository file, not this one. -->\n\n' \
      "$source" "$SHORT" "$TODAY"
    cat "$source"
  } >"$target"
  ok "$title -> $(basename "$target")"
}

hash_of() { ( sha256sum "$1" 2>/dev/null || shasum -a 256 "$1" ) | cut -d' ' -f1; }

bold "Assembling the rest of the handover"
# The notes are named for the tag (v1.0.0.md); older conventions drop the v.
NOTES="docs/release-notes/v$VERSION_NAME.md"
[ -f "$NOTES" ] || NOTES="docs/release-notes/$VERSION_NAME.md"
copy_with_provenance "$NOTES" "$OUT_DIR/RELEASE-NOTES-$VERSION_NAME.md" "release notes"
copy_with_provenance "docs/STORE_CHECKLIST.md" "$OUT_DIR/STORE-CHECKLIST.md" "store checklist"
copy_with_provenance "docs/PRIVACY.md" "$OUT_DIR/PRIVACY.md" "privacy documentation"
copy_with_provenance "docs/RELEASE.md" "$OUT_DIR/RELEASE.md" "release documentation"

OWNER_ZIP="$REPO_ROOT/release-owner-package/WONDER_CV_BUILDER_RELEASE_KEYSTORE.zip"
{
  cat <<EOF
WONDER CV BUILDER — RELEASE HANDOVER
=====================================================================
Version:   $VERSION_NAME ($VERSION_CODE)
Commit:    $SHORT ($COMMIT)
Built on:  $TODAY

FILES HERE
---------------------------------------------------------------------
EOF
  for f in "$OUT_DIR/$FINAL_NAME" "$OUT_DIR/$ANDROID_NAME" \
           "$OUT_DIR/RELEASE-NOTES-$VERSION_NAME.md" "$OUT_DIR/STORE-CHECKLIST.md" \
           "$OUT_DIR/PRIVACY.md" "$OUT_DIR/RELEASE.md"; do
    [ -f "$f" ] || continue
    printf '  %-46s %10s bytes\n    sha256 %s\n' "$(basename "$f")" "$(wc -c <"$f" | tr -d ' ')" "$(hash_of "$f")"
  done
  if [ -f "$OWNER_ZIP" ]; then
    printf '\n  %s\n    %10s bytes\n    sha256 %s\n' \
      "release-owner-package/$(basename "$OWNER_ZIP")" \
      "$(wc -c <"$OWNER_ZIP" | tr -d ' ')" "$(hash_of "$OWNER_ZIP")"
  fi
  cat <<EOF

NOT IN THIS FOLDER, AND THAT IS THE POINT
---------------------------------------------------------------------
  * No keystore, no private key, no password, no API key and no .env. The
    signing key travels separately, in the owner package, and is generated on
    the owner's own machine. tools/check_no_key_material.sh fails this build if
    key material is ever present, and it is the first step of both pipelines.

  * No signed AAB or APK. Those are produced by the release workflow from the
    signing secrets, which is also where their certificate is verified against
    the pinned fingerprint:

        git tag -a v$VERSION_NAME -m "Wonder CV Builder $VERSION_NAME"
        git push origin v$VERSION_NAME

    Without the secrets the workflow stops before it builds anything rather
    than producing an artifact signed with the debug key.

WHAT THIS BUILD IS
---------------------------------------------------------------------
  Wonder CV Builder $VERSION_NAME, a release candidate. Source, tests and
  project configuration are complete; publishing waits on the owner-side steps
  listed in STORE-CHECKLIST.md.
EOF
} >"$OUT_DIR/README.txt"
ok "handover index -> README.txt"

hr
bold "Delivered to $OUT_DIR"
for f in "$OUT_DIR/$FINAL_NAME" "$OUT_DIR/$ANDROID_NAME" "$OUT_DIR/README.txt"; do
  [ -f "$f" ] || die "expected file was not produced: $f"
  printf '  %s\n' "$f"
done
echo
echo "The owner's keystore package is a separate file, built by"
echo "tools/create_owner_package.sh, and is never merged into these two."
