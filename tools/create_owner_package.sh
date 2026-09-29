#!/usr/bin/env bash
#
# Assembles the owner's keystore package: the key, a record with no secrets in
# it, and the instructions for wiring that key into GitHub.
#
#   tools/create_owner_package.sh --keystore ~/wonder-cv-keys/upload.jks
#   tools/create_owner_package.sh --keystore ... --encrypt --backup-dir /media/usb
#   tools/create_owner_package.sh --template      # record only: no key to include
#   tools/create_owner_package.sh --check FILE    # is a package intact?
#
# The result is release-owner-package/WONDER_CV_BUILDER_RELEASE_KEYSTORE.zip.
# That directory is git-ignored, and it has to be: the zip contains a signing
# key.
#
# Rules this script follows, all of them because of what it is packaging:
#
#   * the keystore is never printed, never base64'd into the output, and copied
#     only into the package and into the backup directories the owner names;
#   * a password is never written to a file, never echoed, and never passed as
#     a command-line argument — --encrypt hands the terminal straight to
#     Info-ZIP, so the ZIP password goes from the owner's keyboard into the
#     archive and nowhere else;
#   * the record names the two passwords as fields and never fills them in, so
#     the file the owner keeps holds no secret.
#
# See docs/RELEASE.md for the procedure this fits into.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/release-owner-package"
ZIP_NAME="WONDER_CV_BUILDER_RELEASE_KEYSTORE.zip"
KEYSTORE=""
KEY_ALIAS="upload"
ENCRYPT=0
FINGERPRINT=""
TEMPLATE=0
CHECK_FILE=""
BACKUP_DIRS=()

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
hr()    { printf '%.0s─' {1..72}; printf '\n'; }

usage() { sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --keystore)  KEYSTORE="${2:-}"; shift 2 ;;
    --alias)     KEY_ALIAS="${2:-}"; shift 2 ;;
    --fingerprint) FINGERPRINT="${2:-}"; shift 2 ;;
    --backup-dir) BACKUP_DIRS+=("${2:-}"); shift 2 ;;
    --out-dir)   OUT_DIR="${2:-}"; shift 2 ;;
    --encrypt)   ENCRYPT=1; shift ;;
    --template)  TEMPLATE=1; shift ;;
    --check)     CHECK_FILE="${2:-}"; shift 2 ;;
    -h|--help)   usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

require_tools() {
  command -v zip >/dev/null 2>&1   || die "zip is not on PATH (apt install zip, or brew install zip)."
  command -v unzip >/dev/null 2>&1 || die "unzip is not on PATH."
  if command -v sha256sum >/dev/null 2>&1; then
    sha256_of() { sha256sum "$1" | cut -d' ' -f1; }
  elif command -v shasum >/dev/null 2>&1; then
    sha256_of() { shasum -a 256 "$1" | cut -d' ' -f1; }
  else
    die "neither sha256sum nor shasum is on PATH."
  fi
}

project_version() {
  local version
  version="$(sed -n 's/^version:[[:space:]]*//p' "$REPO_ROOT/pubspec.yaml" 2>/dev/null | head -1)"
  printf '%s' "${version:-1.0.0+1}"
}

version_code() { printf '%s' "${1#*+}"; }
version_name() { printf '%s' "${1%%+*}"; }

# The fingerprint is read from the keystore rather than asked for: a mistyped
# pin is worse than no pin, because the release workflow would then refuse a
# correctly signed artifact. --fingerprint exists for a machine without
# keytool, and the owner can copy the value from tools/create_release_keystore.sh
# --check output.
read_fingerprint() {
  local keystore="$1"
  [ -n "$FINGERPRINT" ] && { printf '%s' "$FINGERPRINT"; return; }
  command -v keytool >/dev/null 2>&1 || return 1
  keytool -list -v -keystore "$keystore" 2>/dev/null \
    | sed -n 's/^[[:space:]]*SHA256: //p;s/^[[:space:]]*Certificate fingerprint (SHA-256): //p' \
    | head -1 | tr -d ':' | tr 'A-F' 'a-f'
}

write_record() {
  local target="$1" name="$2" fingerprint="$3" created="$4" version="$5"
  cat >"$target" <<EOF
WONDER CV BUILDER — RELEASE KEYSTORE OWNER RECORD
=====================================================================
Project:                 Wonder CV Builder
applicationId:           dev.cvpro.builder
versionName:             $(version_name "$version")
versionCode:             $(version_code "$version")
Package built:           $created

KEYSTORE
  Filename:              $name
  Key alias:             $KEY_ALIAS
  Location in package:   keystore/$name
  SHA-256 fingerprint:   $fingerprint
  Keystore password:     <in your password manager — deliberately not written here>
  Key password:          <in your password manager — deliberately not written here>

  This fingerprint is not a secret. It is the identity of the app: the same key
  must sign every future version, and stores show it to anyone who installs it.

BACKUPS — the key must outlive this machine
  Backup 1:              ${BACKUP_1:-<not made yet — copy the keystore somewhere else>}
  Backup 2:              ${BACKUP_2:-<not made yet — and to a different place again>}

  Keep two copies in two locations, encrypted, each with the password available
  separately. Losing this file ends the ability to publish updates to
  dev.cvpro.builder under the same identity, permanently.

GITHUB — repository SECRETS (Settings → Secrets and variables → Actions)
  ANDROID_KEYSTORE_BASE64      base64 of the keystore file
  ANDROID_KEYSTORE_PASSWORD    the keystore password
  ANDROID_KEY_ALIAS            $KEY_ALIAS
  ANDROID_KEY_PASSWORD         the key password

  Set them from files so the values never reach your shell history:
    base64 -w0 "$name" > keystore.base64 && chmod 600 keystore.base64
    gh secret set ANDROID_KEYSTORE_BASE64   < keystore.base64
    gh secret set ANDROID_KEYSTORE_PASSWORD < .store-password
    gh secret set ANDROID_KEY_ALIAS         --body "$KEY_ALIAS"
    gh secret set ANDROID_KEY_PASSWORD      < .key-password
    rm -f keystore.base64 .store-password .key-password

GITHUB — repository VARIABLE (not a secret; it is public information)
  ANDROID_CERT_SHA256          $fingerprint

  gh variable set ANDROID_CERT_SHA256 --body "$fingerprint"

  The release workflow then refuses to publish an artifact signed with any
  other key, which is the one signing mistake a store accepts silently.

WHAT NOT TO DO
  Do not commit this keystore or paste its passwords into a chat, an issue or a
  workflow file. tools/check_no_key_material.sh fails the build if key material
  reaches the repository, and a leaked signing key cannot be un-leaked.
EOF
}

write_readme() {
  local target="$1" name="$2" template="$3"
  if [ "$template" = "1" ]; then
    cat >"$target" <<EOF
WHAT THIS PACKAGE IS
---------------------------------------------------------------------
A template. It holds the owner record for the release keystore and nothing
else, because no release keystore exists in the environment that produced it.
The keystore must be created on the owner's own machine:

    tools/create_release_keystore.sh

Then complete this package, on that same machine:

    tools/create_owner_package.sh --keystore <the file you created> --encrypt

That overwrites WONDER_CV_BUILDER_RELEASE_KEYSTORE.zip with the real thing:
the key, this record with the fingerprint filled in, and the instructions.

WHY IT IS NOT DONE FOR YOU
---------------------------------------------------------------------
A signing key generated in a shared or disposable environment is a key someone
else may have read, and a key written into a chat transcript is a key that
cannot be used. This is the one artifact in the project that has to be created
and kept by its owner.
EOF
    return
  fi
  cat >"$target" <<EOF
WONDER CV BUILDER — RELEASE KEYSTORE PACKAGE
=====================================================================
This package holds the signing identity of the app.

  keystore/$name   the keystore
  OWNER_RECORD.txt      what it is, and what to do with it
  CHECKSUMS.txt         SHA-256 of every file here, to check after copying
  README-FIRST.txt      this file

READ THIS FIRST, IN THIS ORDER
---------------------------------------------------------------------
1. Copy the keystore into your password manager or an encrypted vault, and put
   the keystore password and key password in that same manager. There is no
   recovery path and no way to change them later.

2. Make the two backups the record asks for, in two different places. A backup
   you have never restored is a backup you do not know works: extract the
   keystore from one of them and run
       tools/create_release_keystore.sh --check
   against the extracted file before you trust it.

3. Set the four repository secrets and the one repository variable named in
   OWNER_RECORD.txt. Nothing in this package has to be uploaded to do that;
   the values are read from files, never typed into a command.

4. Then, from the repository, publish:
       git tag -a v1.0.0 -m "Wonder CV Builder 1.0.0"
       git push origin v1.0.0
   The release workflow builds the signed AAB and APK, checks the signature
   against the pinned fingerprint, inspects both, and attaches them to a
   GitHub release. It fails closed if a secret is missing.

KEEPING THIS ZIP
---------------------------------------------------------------------
$( [ "${ENCRYPTED:-0}" = "1" ] && printf '  This zip is password-protected. Its password was typed by you and is not\n  recorded anywhere in the package — put it in your password manager too.\n' || printf '  This zip is NOT encrypted. If it travels anywhere by itself, encrypt it:\n      zip -e %s %s\n' "$ZIP_NAME" "release-owner-package/$ZIP_NAME" )
  Never commit it. release-owner-package/ is git-ignored, and the repository's
  own CI fails if key material appears in a commit.
EOF
}

# ── Check an existing package ────────────────────────────────────────────────

check_package() {
  local file="$1"
  [ -f "$file" ] || die "no such file: $file"
  bold "Package: $file"

  local entries
  entries="$(unzip -Z1 "$file" 2>/dev/null)" || die "unzip could not read $file"
  printf '%s\n' "$entries" | sed 's/^/  /'
  hr

  local problems=0
  for required in OWNER_RECORD.txt README-FIRST.txt; do
    printf '%s\n' "$entries" | grep -qx "$required" || { warn "missing $required"; problems=$((problems + 1)); }
  done

  if printf '%s\n' "$entries" | grep -qE '^keystore/[^/]+$'; then
    ok "the package contains a keystore"
  elif printf '%s\n' "$entries" | grep -q '^KEYSTORE-NOT-INCLUDED-READ-ME-FIRST.txt$'; then
    # Built where no key exists, and says so in a file. That is a deliberate
    # state, not a broken package: the owner completes it on their own machine.
    warn "this is the template package: record and instructions, no keystore"
  else
    warn "neither a keystore nor a note explaining its absence"
    problems=$((problems + 1))
  fi

  # Encryption status is readable without the password, which is the point of
  # checking it here: an unencrypted zip that the owner believes is encrypted is
  # a keystore travelling in the clear.
  if unzip -Z -v "$file" 2>/dev/null | grep -qE "security status:[[:space:]]+encrypted"; then
    ok "entries are encrypted"
  else
    warn "entries are NOT encrypted (fine on this machine; encrypt before it travels)"
  fi

  hr
  printf '  size:    %s bytes\n' "$(wc -c <"$file" | tr -d ' ')"
  printf '  sha256:  %s\n' "$(sha256_of "$file")"
  [ "$problems" -eq 0 ] || die "$problems problem(s) in this package."
  ok "package looks complete"
}

# ── Build ────────────────────────────────────────────────────────────────────

STAGING_DIR=""

build() {
  local template="$1"
  local version created name
  version="$(project_version)"
  created="$(date -u '+%Y-%m-%d %H:%M UTC')"

  if [ "$template" = "0" ]; then
    [ -n "$KEYSTORE" ] || die "--keystore is required (or --template for a record-only package)."
    [ -f "$KEYSTORE" ] || die "no such keystore: $KEYSTORE"
    name="$(basename "$KEYSTORE")"
  else
    name="wonder-cv-builder-upload.jks"
  fi

  local fingerprint
  if [ "$template" = "1" ]; then
    fingerprint="PENDING — create the keystore with tools/create_release_keystore.sh"
  else
    fingerprint="$(read_fingerprint "$KEYSTORE" || true)"
    if [ -z "$fingerprint" ]; then
      warn "no keytool on PATH and no --fingerprint given: the record will say PENDING."
      warn "Fill it in from 'tools/create_release_keystore.sh --check' before you set the variable."
      fingerprint="PENDING — run: keytool -list -v -keystore $name"
    fi
  fi

  # Backups, before packaging: the copy that matters is the one that is not
  # this machine's only copy.
  local index=0
  for dir in "${BACKUP_DIRS[@]:-}"; do
    [ -n "$dir" ] || continue
    index=$((index + 1))
    mkdir -p "$dir" || die "could not create backup directory: $dir"
    cp "$KEYSTORE" "$dir/$name" || die "could not copy the keystore to $dir"
    chmod 600 "$dir/$name"
    case "$index" in
      1) BACKUP_1="$dir/$name" ;;
      2) BACKUP_2="$dir/$name" ;;
    esac
    ok "backup $index: $( [ -n "${dir}" ] && printf '%s' "$dir/$name" )"
  done

  STAGING_DIR="$(mktemp -d)"
  trap 'rm -rf "${STAGING_DIR:-}"' EXIT
  local staging="$STAGING_DIR"

  if [ "$template" = "0" ]; then
    mkdir -p "$staging/keystore"
    cp "$KEYSTORE" "$staging/keystore/$name"
    chmod 600 "$staging/keystore/$name"
    cat >"$staging/KEYSTORE-NOT-INCLUDED-READ-ME-FIRST.txt" <<'EOF'
This file should not be in a package that contains a keystore.
EOF
    rm -f "$staging/KEYSTORE-NOT-INCLUDED-READ-ME-FIRST.txt"
  else
    cat >"$staging/KEYSTORE-NOT-INCLUDED-READ-ME-FIRST.txt" <<'EOF'
NO KEYSTORE IS INSIDE THIS PACKAGE
---------------------------------------------------------------------
This is the record half of the owner package, built in an environment where no
release keystore exists — and where one must not be created, because a key made
on a shared or disposable machine is a key to which someone else may have had
access.

Create the key on your own machine:

    tools/create_release_keystore.sh

Then build the real package from that machine:

    tools/create_owner_package.sh --keystore <the file you just created> --encrypt

The zip will then contain keystore/, OWNER_RECORD.txt, CHECKSUMS.txt and
README-FIRST.txt, and this file will be gone.
EOF
  fi

  write_record  "$staging/OWNER_RECORD.txt" "$name" "$fingerprint" "$created" "$version"
  write_readme  "$staging/README-FIRST.txt" "$name" "$template"

  if [ "$template" = "0" ]; then
    {
      printf '# SHA-256 checksums — verify with: sha256sum -c CHECKSUMS.txt\n\n'
      ( cd "$staging" && find . -type f ! -name CHECKSUMS.txt | sort | while read -r f; do
          printf '%s  %s\n' "$(sha256_of "$f")" "${f#./}"
        done )
    } >"$staging/CHECKSUMS.txt"
  fi

  mkdir -p "$OUT_DIR"
  chmod 700 "$OUT_DIR"
  local out="$OUT_DIR/$ZIP_NAME"
  rm -f "$out"

  hr
  bold "Building $out"
  if [ "$ENCRYPT" = "1" ]; then
    if [ ! -t 2 ]; then
      die "zip -e needs a terminal to read the password. Run this in a terminal, or build unencrypted and encrypt the zip yourself with: zip -e"
    fi
    ENCRYPTED=1
    # Info-ZIP prompts for the password and its confirmation itself, on the
    # terminal: the value never enters this script, a variable, a pipe or argv.
    ( cd "$staging" && zip -r -X -e "$out" . ) >/dev/null || die "zip failed."
  else
    ENCRYPTED=0
    ( cd "$staging" && zip -r -X -q "$out" . ) || die "zip failed."
  fi

  chmod 600 "$out"
  hr
  check_package "$out"
  hr
  if [ "$template" = "1" ]; then
    cat <<EOF
$(bold 'This is the record-only package. To complete it, on the machine that will hold the key:')
   1. tools/create_release_keystore.sh
   2. tools/create_owner_package.sh --keystore <the keystore it created> --encrypt
   3. tools/create_owner_package.sh --check release-owner-package/$ZIP_NAME

   It was built in an environment with no JDK, and one where a signing key must
   not be created: a key made on a shared or disposable machine is a key someone
   else may have read.
EOF
  else
    cat <<EOF
$(bold 'Hand this file to the owner over a channel you trust:')
   $out

$(bold 'Then, on the machine that holds the key:')
   * put the keystore and both passwords in the password manager;
   * set the four secrets and the variable named in OWNER_RECORD.txt;
   * keep the two backups, and test one by extracting it and running
     tools/create_release_keystore.sh --check against it.
EOF
  fi
}

require_tools
if [ -n "$CHECK_FILE" ]; then
  check_package "$CHECK_FILE"
elif [ "$TEMPLATE" = "1" ]; then
  build 1
else
  build 0
fi
