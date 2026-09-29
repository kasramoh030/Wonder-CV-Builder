#!/usr/bin/env bash
#
# Fails if the repository contains signing material or a credential.
#
# Run it before a commit, or let CI run it on every push — it is fast, it is
# offline, and it exists because the alternative to catching this here is
# catching it after it is published, which is never.
#
#   tools/check_no_key_material.sh              # check the working tree and history
#   tools/check_no_key_material.sh --install-hook   # also guard every commit
#
# What it looks for:
#
#   * files that are key material by name — *.jks, *.keystore, *.p12, *.pfx,
#     key.properties, .env, service-account JSON — tracked, staged or merely
#     present in the tree;
#   * key material by content: PEM private-key headers, base64 blobs that
#     decode to a JKS/PKCS12 magic number, and the shapes of the API keys this
#     project could plausibly use;
#   * passwords assigned as literals in a properties or YAML file, which is how
#     a keystore password reaches a commit while the keystore itself does not.
#
# It scans *text* files only. Fonts and images contain byte sequences that
# match key patterns without being keys, and a guard that cries wolf is a
# guard everyone learns to bypass.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

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

# ── By name ──────────────────────────────────────────────────────────────────

name_pattern='(\.jks|\.keystore|\.p12|\.pfx|key\.properties|\.env$|\.env\.|service-account.*\.json|google-services\.json|\.mobileprovision|\.pem|\.key$|secrets\.json|credentials\.json)'

# Tracked files matter most: those are the ones already published.
tracked="$(git ls-files 2>/dev/null | grep -Ei "$name_pattern" || true)"
if [ -n "$tracked" ]; then
  bad "tracked files that look like key material:
$(printf '%s\n' "$tracked" | sed 's/^/      /')"
else
  note "no tracked file is key material by name"
fi

# Untracked-but-present files are the next commit's problem.
untracked="$(git ls-files --others --exclude-standard 2>/dev/null | grep -Ei "$name_pattern" || true)"
if [ -n "$untracked" ]; then
  bad "untracked files in the tree that look like key material (a 'git add -A' would publish them):
$(printf '%s\n' "$untracked" | sed 's/^/      /')"
else
  note "no untracked key material in the working tree"
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
done < <(git ls-files 2>/dev/null)

if [ -n "${content_hits// /}" ]; then
  bad "key-shaped strings in tracked files:
$(printf '%s' "$content_hits" | sed 's/^/      /')"
else
  note "no key-shaped strings in tracked files"
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
done < <(git ls-files 2>/dev/null | head -400)

if [ -n "${base64_hits// /}" ]; then
  bad "base64 that decodes to a JKS/PKCS12 keystore:
$(printf '%s' "$base64_hits" | sort -u | sed 's/^/      /')"
else
  note "no base64-encoded keystore in tracked files"
fi

# ── Passwords written as literals ────────────────────────────────────────────

literal_hits="$(git ls-files 2>/dev/null | grep -E '\.(properties|ya?ml|json|gradle|kts)$' | while read -r candidate; do
  grep -nHiE '^[[:space:]]*(storePassword|keyPassword|password|apiKey|api_key|token)[[:space:]]*[:=][[:space:]]*[^$<{[:space:]][^[:space:]]*' "$candidate" 2>/dev/null \
    | grep -viE '(placeholder|example|your-|<|>|\$\{|process\.env|System\.getenv)' || true
done)"

if [ -n "$literal_hits" ]; then
  bad "a password or key assigned as a literal (it belongs in a secret store):
$(printf '%s' "$literal_hits" | sed 's/^/      /')"
else
  note "no password or key literals in properties, YAML, JSON or Gradle files"
fi

# ── Verdict ──────────────────────────────────────────────────────────────────

echo
if [ "$failures" -eq 0 ]; then
  echo "No key material or credentials found."
  exit 0
fi
cat <<'EOF'
This repository must never contain signing material or credentials.
A leaked signing key cannot be un-leaked: the answer is to revoke it at the
store and start again with a new key, which is a new app listing.

Nothing here has been changed. Remove the material, and if a keystore was
already committed, treat it as compromised.
EOF
exit 1
