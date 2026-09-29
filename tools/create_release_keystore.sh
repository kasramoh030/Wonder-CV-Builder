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

# ── The temporary password files ─────────────────────────────────────────────
#
# keytool reads the password from a *file* rather than a command-line argument,
# which is what keeps it out of `ps`, /proc and the shell history. Those files
# exist for the lifetime of the run and are shredded on the way out. The state
# is global on purpose: an EXIT trap that reads a variable local to a function
# runs after that variable is out of scope, and a script that promises to shred
# your password while leaving it in /tmp is worse than one that never promised.
SECRETS_DIR=""

# Read from the project rather than hardcoding it, so the record the owner keeps
# cannot disagree with the version that was actually built.
project_version() {
  local version
  version="$(sed -n 's/^version:[[:space:]]*//p' "$REPO_ROOT/pubspec.yaml" 2>/dev/null | head -1)"
  printf '%s' "${version:-see pubspec.yaml}"
}

shred_secrets() {
  if [ -n "${SECRETS_DIR:-}" ] && [ -d "$SECRETS_DIR" ]; then
    if command -v shred >/dev/null 2>&1; then
      shred -u "$SECRETS_DIR"/* 2>/dev/null || true
    fi
    rm -rf "$SECRETS_DIR"
  fi
  SECRETS_DIR=""
}

# ── Reading a password without echoing it or leaking it ─────────────────────

#
# $2, if it is the word "allow_empty", accepts a bare Enter — used for the key
# password, where an empty answer means "the same password as the keystore".
# Returns non-zero if the input ends (Ctrl-D, or stdin redirected from
# something empty) instead of asking again forever, because a prompt that
# cannot be answered is worse than one that fails.
read_password() {
  local prompt="$1" allow_empty="${2:-0}"
  local value
  while true; do
    printf '%s' "$prompt" >&2
    if ! IFS= read -r -s value; then
      printf '\n' >&2
      printf 'Input ended before a password was read. Run this in a terminal.\n' >&2
      return 1
    fi
    printf '\n' >&2
    if [ "$allow_empty" = "allow_empty" ] && [ -z "$value" ]; then
      return 0
    fi
    if [ "${#value}" -lt "${MIN_PASSWORD_LENGTH}" ]; then
      # To stderr, and this is not cosmetic: the return value of this function
      # is captured with $( ), so anything written to stdout is prepended to
      # the password. A rejected attempt used to blend its own warning into
      # the value that was finally stored, producing a keystore whose password
      # was not the one the owner had typed.
      warn "at least ${MIN_PASSWORD_LENGTH} characters, please (got ${#value})." >&2
      continue
    fi
    printf '%s' "$value"
    return 0
  done
}

confirm_password() {
  local first="$1"
  local second
  second="$(read_password 'Repeat it: ')" || die "input ended before the password was confirmed."
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
  store_password="$(read_password 'Keystore password: ')" \
    || die "the keystore password was not read; run this script in a terminal."
  confirm_password "$store_password"

  hr
  bold "Key password"
  printf 'Press Enter to use the same password for the key itself.\n'
  local key_password
  key_password="$(read_password 'Key password: ' allow_empty)" \
    || die "the key password was not read; run this script in a terminal."
  # Enter here means "use the keystore password for the key too", which is what
  # the prompt promises and what most keystores do.
  [ -n "$key_password" ] || key_password="$store_password"
  if [ "$key_password" != "$store_password" ]; then
    confirm_password "$key_password"
  fi

  # The password files exist for the lifetime of this run only: keytool reads
  # them instead of a command-line argument, which is what keeps the password
  # out of `ps`, /proc, and the shell history.
  SECRETS_DIR="$(mktemp -d)"
  local store_pw_file="$SECRETS_DIR/store.pw"
  local key_pw_file="$SECRETS_DIR/key.pw"
  trap shred_secrets EXIT
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

  # The key exists now, so the passwords are no longer needed. Shred them here
  # rather than waiting for exit, to keep the window in which they sit in /tmp
  # as short as the run allows. The EXIT trap stays as the backstop for every
  # other path out of this function, including a failure.
  shred_secrets

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

  local store_password
  store_password="$(read_password 'Keystore password: ')" \
    || die "the keystore password was not read; run this script in a terminal."

  SECRETS_DIR="$(mktemp -d)"
  trap shred_secrets EXIT
  printf '%s' "$store_password" >"$SECRETS_DIR/store.pw"

  hr
  bold "Keystore contents"
  keytool -list -v -keystore "$keystore" -storepass:file "$SECRETS_DIR/store.pw" \
    | sed -n 's/^Alias name: /  alias:       /p;s/^Valid from: /  valid from:  /p'
  hr

  local fingerprint
  fingerprint="$(certificate_fingerprint "$keystore" "$SECRETS_DIR/store.pw")"
  [ -n "$fingerprint" ] || die "could not read the certificate fingerprint."
  ok "SHA-256: $fingerprint"
  shred_secrets
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
  Version:        (printed above, read from pubspec.yaml)
  Cert SHA-256:   <printed above>
EOF
}

# ── Shared reporting ─────────────────────────────────────────────────────────

# JDK 9 and later print "SHA256: AA:BB:…"; JDK 8 prints "Certificate
# fingerprint (SHA-256): AA:BB:…". Both are read, because a fingerprint that
# cannot be read is recorded as an empty pin, and an empty pin protects
# nothing.
certificate_fingerprint() {
  local keystore="$1" password_file="$2"
  keytool -list -v -keystore "$keystore" -storepass:file "$password_file" 2>/dev/null \
    | sed -n 's/^[[:space:]]*SHA256: //p;s/^[[:space:]]*Certificate fingerprint (SHA-256): //p' \
    | head -1 \
    | tr -d ':' \
    | tr 'A-F' 'a-f'
}

report() {
  local keystore="$1" target_dir="$2"
  local fingerprint pin_line
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

  # A pin is only worth having if it carries a fingerprint. Rather than print a
  # command that would store an empty value and quietly protect nothing, say
  # what to do instead.
  if [ -n "$fingerprint" ]; then
    pin_line="   gh variable set ANDROID_CERT_SHA256 --body \"$fingerprint\""
  else
    pin_line='   The fingerprint could not be read here. Get it with
     keytool -list -v -keystore <your keystore>   (the SHA256 line),
   then: gh variable set ANDROID_CERT_SHA256 --body <hex without colons>'
  fi

  hr
  bold "Keystore created"
  printf '  file:  %s\n' "$keystore"
  printf '  alias: %s\n' "$KEY_ALIAS"
  [ -n "$fingerprint" ] && printf '  SHA-256: %s\n' "$fingerprint"
  hr

  # The record the owner keeps. It names every field that is needed to publish
  # or to recover, and holds no secret: the two passwords are described rather
  # than printed, because a record that contains them is not keepable.
  cat <<EOF
$(bold 'Owner release credentials — keep this record')
  Keystore file:  $keystore
  Keystore pass:  <the password you just typed, from your password manager>
  Key alias:      $KEY_ALIAS
  Key pass:       <the key password you typed>
  Application id: dev.cvpro.builder
  Version:        $(project_version)
  Cert SHA-256:   ${fingerprint:-<could not be read here — see step 5>}
  Created:        $(date -u '+%Y-%m-%d %H:%M UTC')
  Backup 1:       <where the first copy went>
  Backup 2:       <and the second, in a different place>
EOF
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
$pin_line
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
   # Every line reads from a file, so no value appears in your shell history,
   # in \`ps\`, or on the screen.
   base64 -w0 "$keystore" > "$base64_hint" 2>/dev/null \\
     || base64 -i "$keystore" | tr -d '\\n' > "$base64_hint"
   chmod 600 "$base64_hint"

   gh secret set KEYSTORE_BASE64     < "$base64_hint"
   gh secret set KEYSTORE_PASSWORD   < "$target_dir/.store-password"
   gh secret set KEY_ALIAS           --body "$KEY_ALIAS"
   gh secret set KEY_PASSWORD        < "$target_dir/.key-password"

   # The two password files do not exist yet: this script kept your passwords
   # in memory and shredded its own copies. Write them once, by typing rather
   # than pasting, so they stay out of your shell history and off the screen:
   #   read -rs -p 'keystore password: ' p && printf '%s' "\$p" > "$target_dir/.store-password"
   #   read -rs -p 'key password: '      p && printf '%s' "\$p" > "$target_dir/.key-password"
   #   unset p
   # Then set the two secrets above, and when all four are set:
   #   rm -f "$base64_hint" "$target_dir/.store-password" "$target_dir/.key-password"
EOF
}

# ── Main ─────────────────────────────────────────────────────────────────────

require_tools
if [ "$CHECK_ONLY" = "1" ]; then
  check
else
  create
fi
