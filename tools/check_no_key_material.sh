#!/usr/bin/env bash
#
# Fails if the repository contains signing material or a credential.
#
# Run it before a commit, or let CI run it on every push — it is fast, it is
# offline, and it exists because the alternative to catching this here is
# catching it after it is published, which is never.
#
#   tools/check_no_key_material.sh                  # check the working tree
#   tools/check_no_key_material.sh --install-hook   # also guard every commit
#   tools/check_no_key_material.sh --dir PATH       # check a plain directory
#
# --dir is for something that is not a git repository: an unpacked delivery
# archive, a build output, a folder someone sent you. It is the same checks over
# every file in the tree, which is what lets the release packaging step prove
# that what it just built contains no key material.
#
# What it looks for:
#
#   * files that are key material by name — *.jks, *.keystore, *.p12, *.pfx,
#     key.properties, .env, service-account JSON — tracked, staged or merely
#     present in the tree;
#   * key material by content: PEM private-key headers, base64 blobs that
#     decode to a JKS/PKCS12 magic number, and the shapes of the API keys this
#     project could plausibly use;
#   * credentials written as literals — a quoted value anywhere, or an unquoted
#     value in properties, YAML or JSON — which is how a keystore password
#     reaches a commit while the keystore itself does not. A line that reads
#     its value from the environment is not a literal, and is not reported.
#
# It scans *text* files only. Fonts and images contain byte sequences that
# match key patterns without being keys, and a guard that cries wolf is a
# guard everyone learns to bypass.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SCAN_DIR=""
if [ "${1:-}" = "--dir" ]; then
  SCAN_DIR="${2:-}"
  [ -n "$SCAN_DIR" ] || { printf 'error: --dir needs a path\n' >&2; exit 2; }
  [ -d "$SCAN_DIR" ] || { printf 'error: not a directory: %s\n' "$SCAN_DIR" >&2; exit 2; }
  SCAN_DIR="$(cd "$SCAN_DIR" && pwd)"
  cd "$SCAN_DIR" || exit 2
else
  cd "$REPO_ROOT" || exit 2
fi

failures=0
note() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; failures=$((failures + 1)); }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }

if [ "${1:-}" = "--install-hook" ]; then
  hooks_dir="$REPO_ROOT/.git/hooks"
  mkdir -p "$hooks_dir"
  cat >"$hooks_dir/pre-commit" <<'HOOK'
#!/usr/bin/env bash
# Installed by tools/check_no_key_material.sh --install-hook
exec "$(git rev-parse --show-toplevel)/tools/check_no_key_material.sh"
HOOK
  chmod +x "$hooks_dir/pre-commit"
  note "pre-commit hook installed (it runs this check before every commit)"
  exit 0
fi

echo "Checking for key material and credentials..."
[ -n "$SCAN_DIR" ] && echo "  (scanning the directory $SCAN_DIR)"

# The file list, in whichever mode we are in. In a repository that is what git
# tracks; in a plain directory it is everything except .git, because a delivery
# archive has no index to consult.
files() {
  if [ -n "$SCAN_DIR" ]; then
    find . -path ./.git -prune -o -type f -print | sed 's|^\./||' | sort
  else
    git ls-files 2>/dev/null
  fi
}

# ── By name ──────────────────────────────────────────────────────────────────

name_pattern='(\.jks|\.keystore|\.p12|\.pfx|key\.properties|\.env$|\.env\.|service-account.*\.json|google-services\.json|\.mobileprovision|\.pem|\.key$|secrets\.json|credentials\.json)'

# Tracked files matter most: those are the ones already published.
tracked="$(files | grep -Ei "$name_pattern" || true)"
if [ -n "$tracked" ]; then
  bad "files that look like key material:
$(printf '%s\n' "$tracked" | sed 's/^/      /')"
else
  [ -n "$SCAN_DIR" ] && note "no file in the directory is key material by name" \
                     || note "no tracked file is key material by name"
fi

# Untracked-but-present files are the next commit's problem. Only a repository
# has that distinction; in a directory everything above was already scanned.
if [ -z "$SCAN_DIR" ]; then
  untracked="$(git ls-files --others --exclude-standard 2>/dev/null | grep -Ei "$name_pattern" || true)"
  if [ -n "$untracked" ]; then
    bad "untracked files in the tree that look like key material (a 'git add -A' would publish them):
$(printf '%s\n' "$untracked" | sed 's/^/      /')"
  else
    note "no untracked key material in the working tree"
  fi
fi

# ── By content, in tracked text files ────────────────────────────────────────

content_hits=""
while IFS= read -r candidate; do
  [ -f "$candidate" ] || continue
  # Text only: a font's metadata contains strings that match key shapes.
  grep -Iq . "$candidate" 2>/dev/null || continue
  hit="$(grep -nHoE \
    '(-----BEGIN [A-Z ]*PRIVATE KEY-----|sk-(proj-)?[A-Za-z0-9_-]{32,}|AIza[0-9A-Za-z_-]{35}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{60,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,})' \
    "$candidate" 2>/dev/null | head -2 || true)"
  [ -n "$hit" ] && content_hits="$content_hits$hit"$'\n'
done < <(files)

if [ -n "${content_hits// /}" ]; then
  bad "key-shaped strings in the scanned files:
$(printf '%s' "$content_hits" | sed 's/^/      /')"
else
  note "no key-shaped strings in the scanned files"
fi

# A base64 blob that decodes to a JKS or PKCS12 magic number is a keystore
# inside a text file, which is the form it takes when someone commits one.
base64_hits=""
while IFS= read -r candidate; do
  [ -f "$candidate" ] || continue
  grep -Iq . "$candidate" 2>/dev/null || continue
  while IFS= read -r blob; do
    [ "${#blob}" -ge 200 ] || continue
    magic="$(printf '%s' "$blob" | base64 -d 2>/dev/null | head -c 4 | od -An -tx1 | tr -d ' \n')"
    case "$magic" in
      feedfeed|cececece) base64_hits="$base64_hits$candidate"$'\n' ;;
    esac
  done < <(grep -oE '[A-Za-z0-9+/]{200,}={0,2}' "$candidate" 2>/dev/null | head -3)
done < <(files | head -400)

if [ -n "${base64_hits// /}" ]; then
  bad "base64 that decodes to a JKS/PKCS12 keystore:
$(printf '%s' "$base64_hits" | sort -u | sed 's/^/      /')"
else
  note "no base64-encoded keystore in the scanned files"
fi

# ── Passwords written as literals ────────────────────────────────────────────
#
# The two shapes here must be told apart, because a guard that cannot is a
# guard people learn to bypass. `storePassword = releaseStorePassword` in a
# Gradle file refers to a variable; it is exactly how the release build is
# *supposed* to read its credentials out of the environment. The same line with
# `storePassword = "hunter2"` has the secret committed to the repository. So a
# quoted value counts as a literal anywhere, and only in the formats where an
# unquoted value is data rather than a reference — properties, YAML, JSON —
# does a bare value count as one too.
#
# This file is skipped here on purpose: it quotes the pattern it looks for, and
# a checker that reports its own documentation teaches people to ignore it. The
# other checks still read it, so key material hidden in here would not survive.

credential_names='(storePassword|keyPassword|password|passwd|apiKey|api_key|apiSecret|privateKey|private_key|clientSecret|token|secret)'
# A value that is a reference, a lookup or a documented placeholder rather than
# a secret: an environment variable, a command substitution, a template
# placeholder, an example, a row of x's.
credential_noise='(placeholder|example|your[-_]|dummy|redacted|fake|\$\{|\$\(|\$[A-Za-z_]|getenv|process\.env|System\.getenv|<[^>]*>|[x*]{6,})'
candidates="$(files | grep -vE '(^|/)tools/check_no_key_material\.sh$' || true)"

quoted_hits="$(printf '%s\n' "$candidates" | grep -E '\.(properties|gradle|kts|ya?ml|json|dart|sh|toml|ini|cfg)$' | while read -r candidate; do
  grep -nHiE "$credential_names[[:space:]]*[:=][[:space:]]*[\"'\`][^\"'\`]{3,}[\"'\`]" "$candidate" 2>/dev/null || true
done | grep -viE "$credential_noise" || true)"

bare_hits="$(printf '%s\n' "$candidates" | grep -E '\.(properties|ya?ml|json)$' | while read -r candidate; do
  grep -nHiE "$credential_names[[:space:]]*[:=][[:space:]]*(changeit|[A-Za-z0-9_+/=-]{6,})" "$candidate" 2>/dev/null || true
done | grep -viE "$credential_noise" || true)"

literal_hits="$(printf '%s\n%s\n' "$quoted_hits" "$bare_hits" | grep -v '^[[:space:]]*$' || true)"

if [ -n "$literal_hits" ]; then
  bad "a credential written as a literal (it belongs in a secret store):
$(printf '%s' "$literal_hits" | sort -u | sed 's/^/      /')"
else
  note "no credential literals in code or configuration files"
fi

# ── Verdict ──────────────────────────────────────────────────────────────────

echo
if [ "$failures" -eq 0 ]; then
  echo "No key material or credentials found."
  exit 0
fi
cat <<'EOF'
This tree must never contain signing material or credentials.
A leaked signing key cannot be un-leaked: the answer is to revoke it at the
store and start again with a new key, which is a new app listing.

Nothing here has been changed. Remove the material, and if a keystore was
already committed, treat it as compromised.
EOF
exit 1
