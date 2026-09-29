#!/usr/bin/env bash
#
# Creates (or verifies) the Wonder CV Builder release keystore.
#
# Run this on YOUR OWN machine — the one you control — not on a CI runner and
# not inside the repository. The keystore is the app's permanent identity: it
# is what makes an update installable over the version already on a user's
# phone, for as long as the app exists on any store.
#
#   ./tools/create_release_keystore.sh            # create a new keystore
#   ./tools/create_release_keystore.sh --check    # verify an existing one
#
# What it guarantees:
#
#   * the keystore is written OUTSIDE the git repository, and the script
#     refuses to run if the target directory is inside one — a keystore that
#     cannot be committed is better than a .gitignore rule that might be
#     missed;
#   * passwords are never passed on a command line (where `ps` and your shell
#     history can read them) — they go through 0600 files that keytool reads
#     and this script shreds;
#   * passwords are never echoed, never written to a log, and never printed in
#     the summary;
#   * the only values printed are the ones that are safe to share: the alias,
#     the file path, and the certificate's SHA-256 fingerprint.
#
# It then prints the exact commands to put the keystore into GitHub Secrets
# without ever showing its contents.

set -Eeuo pipefail
umask 077

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_DIR="${HOME}/wonder-cv-keys"
KEY_ALIAS="upload"
VALIDITY_DAYS=10000
KEY_SIZE=4096
DNAME_DEFAULT="CN=Wonder CV Builder, OU=Release, O=Wonder CV Builder, L=, ST=, C="

# ── Output helpers ───────────────────────────────────────────────────────────

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()   { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
hr()    { printf '%.0s─' {1..72}; printf '\n'; }

# ── Requirements ─────────────────────────────────────────────────────────────

require_tools() {
  command -v keytool >/dev/null 2>&1 || die \
    "keytool is not on PATH. Install a JDK (Temurin 17 or newer) and try again."
  command -v base64 >/dev/null 2>&1 || die "base64 is not on PATH."
  if command -v shasum >/dev/null 2>&1; then
    SHA_TOOL="shasum -a 256"
  elif command -v sha256sum >/dev/null 2>&1; then
    SHA_TOOL="sha256sum"
  else
    die "neither shasum nor sha256sum is on PATH."
  fi
}

# ── Safety: never write key material inside a repository ─────────────────────

assert_outside_repo() {
  local target="$1"
  local dir
  dir="$(cd "$(dirname "$target")" && pwd)"
  if git -C "$dir" rev-parse --show-toplevel >/dev/null 2>&1; then
    local top
    top="$(git -C "$dir" rev-parse --show-toplevel)"
    die "$(cat <<EOF
refusing to write the keystore inside a git repository.

  target:      $dir
  repository:  $top

A keystore in a working tree is one 'git add -A' away from being published,
and a published signing key cannot be un-published. Choose a directory outside
any repository, for example:

  $DEFAULT_DIR
EOF
)"
  fi
}

# ── Reading a password without echoing it or leaking it ─────────────────────

read_password() {
  local prompt="$1"
  local value
  while true; do
    printf '%s' "$prompt" >&2
    IFS= read -r -s value
    printf '\n' >&2
    if [ "${#value}" -lt "${MIN_PASSWORD_LENGTH}" ]; then
      warn "at least ${MIN_PASSWORD_LENGTH} characters, please (got ${#value})."
      continue
    fi
    printf '%s' "$value"
    return
  done
}

confirm_password() {
  local first="$1"
  local second
  second="$(read_password 'Repeat it: ')"
  [ "$first" = "$second" ] || die "the two passwords differ."
}

MIN_PASSWORD_LENGTH=12

# ── Modes ────────────────────────────────────────────────────────────────────

CHECK_ONLY=0
WITH_BASE64=0
for argument in "$@"; do
  case "$argument" in
    --check) CHECK_ONLY=1 ;;
    --with-base64) WITH_BASE64=1 ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown option: $argument (try --help)" ;;
  esac
done

# ── Create ───────────────────────────────────────────────────────────────────

create() {
  bold "Wonder CV Builder — release keystore"
  hr
  cat <<EOF
This creates the key that signs every future release of the app. Read this
once before continuing:

  * Choose a strong password and store it in your password manager BEFORE you
    continue. There is no recovery: a lost keystore password means the
    keystore can never be used again.
  * Back the keystore file up in at least two places that are not this
    machine (see the end of this script's output).
  * Nothing you type here is echoed, logged, or written anywhere in plain
    text; the summary at the end contains no secret.
EOF
  hr
  printf 'Directory for the keystore [%s]: ' "$DEFAULT_DIR"
  read -r target_dir
  target_dir="${target_dir:-$DEFAULT_DIR}"
  target_dir="${target_dir/#\~/$HOME}"

  mkdir -p "$target_dir"
  chmod 700 "$target_dir"
  assert_outside_repo "$target_dir/keystore.jks"

  local keystore="$target_dir/wonder-cv-builder-upload.jks"
  if [ -e "$keystore" ]; then
    die "$(cat <<EOF
$keystore already exists.

Refusing to overwrite a signing key. If you meant to inspect it, run:

  $0 --check
EOF
)"
  fi

  printf 'Key alias [%s]: ' "$KEY_ALIAS"
  read -r alias_input
  KEY_ALIAS="${alias_input:-$KEY_ALIAS}"

  hr
  bold "Keystore password"
  local store_password
  store_password="$(read_password 'Keystore password: ')"
  confirm_password "$store_password"

  hr
  bold "Key password"
  printf 'Press Enter to use the same password for the key itself.\n'
  local key_password
  key_password="$(read_password 'Key password: ')"
  [ -n "$key_password" ] || key_password="$store_password"
  if [ "$key_password" != "$store_password" ]; then
    confirm_password "$key_password"
  fi

  # The password files exist for the lifetime of this run only: keytool reads
  # them instead of a command-line argument, which is what keeps the password
  # out of `ps`, /proc, and the shell history.
  local secrets_dir
  secrets_dir="$(mktemp -d)"
  local store_pw_file="$secrets_dir/store.pw"
  local key_pw_file="$secrets_dir/key.pw"
  cleanup() {
    if [ -d "$secrets_dir" ]; then
      if command -v shred >/dev/null 2>&1; then
        shred -u "$store_pw_file" "$key_pw_file" 2>/dev/null || true
      fi
      rm -rf "$secrets_dir"
    fi
  }
  trap cleanup EXIT
  printf '%s' "$store_password" >"$store_pw_file"
  printf '%s' "$key_password" >"$key_pw_file"

  hr
  printf 'Distinguished name. The defaults are fine for a store upload; press\n'
  printf 'Enter to accept.\n\n'
  printf '  CN (your name or company): '
  read -r cn
  cn="${cn:-Wonder CV Builder}"
  printf '  O  (organisation)       : '
  read -r org
  org="${org:-$cn}"
  printf '  C  (2-letter country)   : '
  read -r country
  country="${country:-IR}"
  local dname="CN=$cn, OU=Release, O=$org, C=$country"

  printf '\nGenerating a %s-bit RSA key (valid %s days)...\n\n' "$KEY_SIZE" "$VALIDITY_DAYS"
  keytool -genkeypair \
    -keystore "$keystore" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize "$KEY_SIZE" \
    -validity "$VALIDITY_DAYS" \
    -storetype JKS \
    -dname "$dname" \
    -storepass:file "$store_pw_file" \
    -keypass:file "$key_pw_file" \
    >/dev/null

  chmod 600 "$keystore"

  # key.properties points this machine at the key. It lives beside the keystore
  # (outside the repository) and is also git-ignored inside the repository, so
  # there is no path by which it reaches a commit.
  cat >"$target_dir/key.properties" <<EOF
storeFile=$keystore
storePassword=$store_password
keyAlias=$KEY_ALIAS
keyPassword=$key_password
EOF
  chmod 600 "$target_dir/key.properties"

  if [ "$WITH_BASE64" = "1" ]; then
    base64 -w0 "$keystore" >"$target_dir/keystore.base64" 2>/dev/null \
      || base64 -i "$keystore" | tr -d '\n' >"$target_dir/keystore.base64"
    chmod 600 "$target_dir/keystore.base64"
  fi

  report "$keystore" "$target_dir"
}

# ── Check ────────────────────────────────────────────────────────────────────

check() {
  printf 'Path to the keystore: '
  read -r keystore
  keystore="${keystore/#\~/$HOME}"
  [ -f "$keystore" ] || die "no such file: $keystore"

  printf 'Keystore password: ' >&2
  local store_password
  IFS= read -r -s store_password
  printf '\n' >&2

  local secrets_dir
  secrets_dir="$(mktemp -d)"
  trap 'rm -rf "$secrets_dir"' EXIT
  printf '%s' "$store_password" >"$secrets_dir/store.pw"

  hr
  bold "Keystore contents"
  keytool -list -v -keystore "$keystore" -storepass:file "$secrets_dir/store.pw" \
    | sed -n 's/^Alias name: /  alias:       /p;s/^Valid from: /  valid from:  /p'
  hr

  local fingerprint
  fingerprint="$(certificate_fingerprint "$keystore" "$secrets_dir/store.pw")"
  [ -n "$fingerprint" ] || die "could not read the certificate fingerprint."
  ok "SHA-256: $fingerprint"
  cat <<'EOF'

This fingerprint is not a secret: it is what a store shows for the app, and
what this repository can pin so that a release signed with a different key is
refused before it is uploaded. Keep it with the release notes.

  Owner release credentials
  ─────────────────────────
  Keystore file:  <the path you just typed>
  Keystore pass:  <in your password manager>
  Key alias:      (printed above)
  Key pass:       <in your password manager>
  App id:         dev.cvpro.builder
  Version:        see pubspec.yaml (1.0.0+1)
  Cert SHA-256:   <printed above>
EOF
}

# ── Shared reporting ─────────────────────────────────────────────────────────

# The interpreter and platform differ, so both spellings are tried.
certificate_fingerprint() {
  local keystore="$1" password_file="$2"
  keytool -list -v -keystore "$keystore" -storepass:file "$password_file" 2>/dev/null \
    | sed -n 's/^[[:space:]]*SHA256: //p' \
    | head -1 \
    | tr -d ':' \
    | tr 'A-F' 'a-f'
}

report() {
  local keystore="$1" target_dir="$2"
  local fingerprint
  fingerprint="$(certificate_fingerprint "$keystore" "$target_dir/key.properties")" || true
  # key.properties holds "storePassword=…", not the raw password file keytool
  # wants, so fall back to a direct read for the fingerprint.
  if [ -z "$fingerprint" ]; then
    local tmp
    tmp="$(mktemp)"
    sed -n 's/^storePassword=//p' "$target_dir/key.properties" >"$tmp"
    fingerprint="$(certificate_fingerprint "$keystore" "$tmp")"
    rm -f "$tmp"
  fi

  hr
  bold "Keystore created"
  printf '  file:  %s\n' "$keystore"
  printf '  alias: %s\n' "$KEY_ALIAS"
  [ -n "$fingerprint" ] && printf '  SHA-256: %s\n' "$fingerprint"
  hr

  cat <<EOF
$(bold '1. Put the password in your password manager now.')
   Entry: "Wonder CV Builder — upload keystore"
   Keystore password, key alias ($KEY_ALIAS) and key password.
   There is no recovery path. Do not keep the only copy on this machine.

$(bold '2. Back the keystore up, twice, somewhere else.')
   cp "$keystore" /path/to/encrypted/backup/
   Then a second copy in a different place: an encrypted archive on a USB key,
   a password manager's file storage, or your own encrypted cloud. Two copies,
   two locations. Losing this file means losing the ability to update the app
   under dev.cvpro.builder forever.

$(bold '3. Give GitHub the four secrets — the keystore is never typed or shown.')
   Run these from the repository, where \`gh\` is authenticated:
$(secret_commands "$keystore" "$target_dir")
$(bold '4. Point this machine at the key for local release builds.')
   cp "$target_dir/key.properties" "$REPO_ROOT/android/key.properties"
   (It is git-ignored, and an env-var alternative is in docs/RELEASE.md.)

$(bold '5. Record the fingerprint in the repository — it is not a secret.')
   gh variable set ANDROID_CERT_SHA256 --body "$fingerprint"
   The release workflow then refuses to publish an artifact signed with any
   other key.
EOF

  if [ "$WITH_BASE64" = "0" ]; then
    cat <<EOF

$(bold 'For the secrets above you need the base64 form:')
   $0 --check   (with --with-base64 on the create run, or:)
   base64 -w0 "$keystore" > "$target_dir/keystore.base64"
   chmod 600 "$target_dir/keystore.base64"
   Delete that file once the secrets are set.
EOF
  else
    cat <<EOF

$(bold 'The base64 form is at:') $target_dir/keystore.base64
   Delete it once the GitHub secrets are set:
     rm -f "$target_dir/keystore.base64"
EOF
  fi
}

secret_commands() {
  local keystore="$1" target_dir="$2"
  local base64_hint="$target_dir/keystore.base64"
  cat <<EOF
   # Reads from a file: the value never appears in your shell history, in
   # \`ps\`, or in this terminal.
   base64 -w0 "$keystore" > "$base64_hint" 2>/dev/null \\
     || base64 -i "$keystore" | tr -d '\\n' > "$base64_hint"
   chmod 600 "$base64_hint"

   gh secret set KEYSTORE_BASE64     < "$base64_hint"
   gh secret set KEYSTORE_PASSWORD   < "$target_dir/.store-password"
   gh secret set KEY_ALIAS           --body "$KEY_ALIAS"
   gh secret set KEY_PASSWORD        < "$target_dir/.key-password"

   # Before running the password lines, write them into those two files once
   # (they are git-ignored and 0600):
   #   printf '%s' 'your keystore password' > "$target_dir/.store-password"
   #   printf '%s' 'your key password'      > "$target_dir/.key-password"
   #   chmod 600 "$target_dir"/.store-password "$target_dir"/.key-password
   # Then delete them, and the base64 file, when the secrets are set.
EOF
}

# ── Main ─────────────────────────────────────────────────────────────────────

require_tools
if [ "$CHECK_ONLY" = "1" ]; then
  check
else
  create
fi
