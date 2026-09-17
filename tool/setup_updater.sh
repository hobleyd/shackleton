#!/usr/bin/env bash
#
# One-time (and re-runnable) setup for Shackleton's in-app updater.
#
# The app ships with the *public* half of the release signing key pinned in
# lib/widgets/shackleton_update.dart and committed as desktop_updater.keys.json.
# Everything the release workflow needs beyond that lives outside the
# repository, and this script puts it there:
#
#   1. Generates the signing keypair if there isn't one yet.
#   2. Checks the public key the app pins still matches the key profile --
#      a mismatch means the app cannot verify anything the workflow signs.
#   3. Exports the encrypted private bundle and loads it, with its
#      passphrase, into the repo as GitHub Actions secrets.
#   4. Checks the gh-pages branch the workflow publishes to exists.
#   5. Turns on GitHub Pages for that branch.
#
# Safe to re-run: every step reports what is already in place and does
# nothing unless something is missing or --force is given. Nothing is
# written to the working tree; the private key never touches it.
#
# Usage:
#   tool/setup_updater.sh                 # set up whatever is missing, prompting
#   tool/setup_updater.sh --check         # report only, change nothing
#   tool/setup_updater.sh --force         # re-issue the secrets even if present
#   tool/setup_updater.sh --yes           # don't prompt
#   tool/setup_updater.sh --repo o/r      # target a repo other than origin's

set -euo pipefail

SECRET_BUNDLE="DESKTOP_UPDATER_KEY_BUNDLE_B64"
SECRET_PASSPHRASE="DESKTOP_UPDATER_KEY_PASSPHRASE"
PAGES_BRANCH="gh-pages"
KEY_PROFILE="desktop_updater.keys.json"
SERVICE_FILE="lib/widgets/shackleton_update.dart"

CHECK_ONLY=0
FORCE=0
ASSUME_YES=0
REPO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK_ONLY=1 ;;
    --force) FORCE=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --repo) REPO="${2:-}"; shift ;;
    -h|--help)
      # Every comment line of the header block, up to the first line that
      # isn't one -- so the help can never drift from the header again.
      awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"
      exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 64 ;;
  esac
  shift
done

# ── output ────────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  BOLD=$(printf '\033[1m'); DIM=$(printf '\033[2m'); RED=$(printf '\033[31m')
  GREEN=$(printf '\033[32m'); YELLOW=$(printf '\033[33m'); OFF=$(printf '\033[0m')
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; OFF=""
fi

step() { printf '\n%s==>%s %s%s%s\n' "$BOLD" "$OFF" "$BOLD" "$1" "$OFF"; }
ok()   { printf '    %s✓%s %s\n' "$GREEN" "$OFF" "$1"; }
warn() { printf '    %s!%s %s\n' "$YELLOW" "$OFF" "$1"; }
info() { printf '    %s%s%s\n' "$DIM" "$1" "$OFF"; }
die()  { printf '\n%serror:%s %s\n' "$RED" "$OFF" "$1" >&2; exit 1; }

# Returns 0 if the user agrees. --check never agrees; --yes always does.
confirm() {
  [ "$CHECK_ONLY" -eq 1 ] && { info "would: $1"; return 1; }
  [ "$ASSUME_YES" -eq 1 ] && return 0
  printf '    %s? %s [y/N] ' "$YELLOW$OFF" "$1"
  read -r reply </dev/tty || return 1
  case "$reply" in [yY]*) return 0 ;; *) return 1 ;; esac
}

# ── preflight ─────────────────────────────────────────────────────────────────
step "Checking prerequisites"

command -v gh   >/dev/null 2>&1 || die "the GitHub CLI (gh) is not installed -- https://cli.github.com"
command -v dart >/dev/null 2>&1 || die "dart is not on PATH"
command -v git  >/dev/null 2>&1 || die "git is not on PATH"
command -v python3 >/dev/null 2>&1 || die "python3 is not on PATH (used to read $KEY_PROFILE)"
command -v openssl >/dev/null 2>&1 || die "openssl is not on PATH (used to generate the passphrase)"

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) \
  || die "not inside a git repository"
cd "$REPO_ROOT"

[ -f pubspec.yaml ] || die "no pubspec.yaml in $REPO_ROOT -- is this the Shackleton repo?"
[ -f "$SERVICE_FILE" ] || die "$SERVICE_FILE is missing -- the updater code is not in this checkout"

if ! gh auth status >/dev/null 2>&1; then
  die "gh is not authenticated. Run: gh auth login"
fi
ok "gh is authenticated"

if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) \
    || die "could not determine the repository -- pass --repo owner/name"
fi
ok "target repository: $REPO"

# Setting secrets and enabling Pages both need admin on the repo. Failing
# here with a clear message beats failing halfway through with a raw 403.
if ! gh api "repos/$REPO" --jq '.permissions.admin' 2>/dev/null | grep -q true; then
  warn "you may not have admin on $REPO -- setting secrets and enabling Pages will fail without it"
fi

[ "$CHECK_ONLY" -eq 1 ] && info "--check: reporting only, nothing will be changed"

# ── 1. signing keypair ────────────────────────────────────────────────────────
step "Release signing keypair"

if [ -f "$KEY_PROFILE" ]; then
  ok "$KEY_PROFILE exists"
else
  warn "$KEY_PROFILE is missing"
  if confirm "generate a new signing keypair?"; then
    dart run desktop_updater:release keygen >/dev/null \
      || die "keygen failed"
    ok "generated $KEY_PROFILE (private half stored outside the repo)"
  else
    die "cannot continue without a key profile"
  fi
fi

ACTIVE_KEY_ID=$(python3 -c "import json;print(json.load(open('$KEY_PROFILE'))['activeKeyId'])")
ACTIVE_KEY=$(python3 -c "import json;d=json.load(open('$KEY_PROFILE'));print(d['publicKeys'][d['activeKeyId']])")
info "active key id: $ACTIVE_KEY_ID"

# ── 2. the app must pin the key the workflow signs with ───────────────────────
step "Public key pinned in the app"

if grep -q "$ACTIVE_KEY_ID" "$SERVICE_FILE" && grep -q "$ACTIVE_KEY" "$SERVICE_FILE"; then
  ok "trustedReleasePublicKeys matches $KEY_PROFILE"
else
  warn "the key pinned in $SERVICE_FILE does not match $KEY_PROFILE"
  cat <<EOF

    A build that pins a different key cannot verify anything this workflow
    signs, so every update check will fail. Update the constant to:

        const Map<String, String> _trustedReleasePublicKeys = {
          '$ACTIVE_KEY_ID':
              '$ACTIVE_KEY',
        };

    Also update the matching "releaseRootPublicKeys" entry in
    macos/Runner/DesktopUpdaterHelperPolicy.json:

        {"algorithm":"ed25519","keyId":"$ACTIVE_KEY_ID","publicKeyBase64":"$ACTIVE_KEY"}

    If you are rotating keys, keep the OLD entry alongside the new one for
    one release -- a client still on the previous build verifies with the
    old key.

EOF
  [ "$CHECK_ONLY" -eq 1 ] || die "fix the pinned key, then re-run"
fi

# ── 3. secrets ────────────────────────────────────────────────────────────────
step "GitHub Actions secrets"

# `gh secret list --json` needs a reasonably recent gh; fall back to the
# plain tabular output, whose first column is the name, when it isn't
# available.
secret_exists() {
  local names
  names=$(gh secret list --repo "$REPO" --json name --jq '.[].name' 2>/dev/null) \
    || names=$(gh secret list --repo "$REPO" 2>/dev/null | awk '{print $1}')
  printf '%s\n' "$names" | grep -qx "$1"
}

HAVE_BUNDLE=0; secret_exists "$SECRET_BUNDLE"     && HAVE_BUNDLE=1
HAVE_PASS=0;   secret_exists "$SECRET_PASSPHRASE" && HAVE_PASS=1

if [ "$HAVE_BUNDLE" -eq 1 ] && [ "$HAVE_PASS" -eq 1 ] && [ "$FORCE" -eq 0 ]; then
  ok "$SECRET_BUNDLE is set"
  ok "$SECRET_PASSPHRASE is set"
  info "pass --force to re-issue them (needed after rotating the key)"
else
  [ "$HAVE_BUNDLE" -eq 1 ] || warn "$SECRET_BUNDLE is not set"
  [ "$HAVE_PASS" -eq 1 ]   || warn "$SECRET_PASSPHRASE is not set"
  [ "$FORCE" -eq 1 ]       && warn "--force: re-issuing both secrets"

  # The passphrase only ever protects the exported bundle in transit to
  # GitHub; both halves live as secrets, so a generated one is strictly
  # better than a memorable one -- there is nothing for a human to type
  # later.
  if confirm "export the private key and upload both secrets to $REPO?"; then
    TMPDIR_SECURE=$(mktemp -d)
    chmod 700 "$TMPDIR_SECURE"
    # shellcheck disable=SC2064
    trap "rm -rf '$TMPDIR_SECURE'" EXIT INT TERM

    DESKTOP_UPDATER_KEY_PASSPHRASE=$(openssl rand -base64 32 | tr -d '\n')
    export DESKTOP_UPDATER_KEY_PASSPHRASE

    dart run desktop_updater:release keys export \
      --output "$TMPDIR_SECURE/release-key.dukey" \
      --passphrase-env DESKTOP_UPDATER_KEY_PASSPHRASE \
      --force >/dev/null \
      || die "key export failed -- is the private key still in the local key store?"

    base64 < "$TMPDIR_SECURE/release-key.dukey" | tr -d '\n' \
      > "$TMPDIR_SECURE/bundle.b64"
    printf '%s' "$DESKTOP_UPDATER_KEY_PASSPHRASE" > "$TMPDIR_SECURE/passphrase"

    # Piped, not passed as --body: an argument would be visible in `ps` to
    # every other process on the machine while gh runs.
    gh secret set "$SECRET_BUNDLE" --repo "$REPO" < "$TMPDIR_SECURE/bundle.b64" \
      || die "could not set $SECRET_BUNDLE"
    ok "set $SECRET_BUNDLE ($(wc -c < "$TMPDIR_SECURE/bundle.b64" | tr -d ' ') bytes)"

    gh secret set "$SECRET_PASSPHRASE" --repo "$REPO" < "$TMPDIR_SECURE/passphrase" \
      || die "could not set $SECRET_PASSPHRASE"
    ok "set $SECRET_PASSPHRASE (freshly generated)"

    unset DESKTOP_UPDATER_KEY_PASSPHRASE
    rm -rf "$TMPDIR_SECURE"
    trap - EXIT INT TERM
    ok "temporary key material removed"
  fi
fi

# ── 4. the branch the workflow publishes to ───────────────────────────────────
step "gh-pages branch"

if git ls-remote --exit-code --heads origin "$PAGES_BRANCH" >/dev/null 2>&1; then
  ok "$PAGES_BRANCH exists on origin"
else
  warn "$PAGES_BRANCH does not exist"
  info "the workflow's deploy job creates it on first push to main"
fi

# ── 5. GitHub Pages ───────────────────────────────────────────────────────────
step "GitHub Pages"

PAGES_JSON=$(gh api "repos/$REPO/pages" 2>/dev/null || true)

if [ -n "$PAGES_JSON" ]; then
  CURRENT_BRANCH=$(printf '%s' "$PAGES_JSON" | python3 -c "import json,sys;print(json.load(sys.stdin).get('source',{}).get('branch',''))" 2>/dev/null || echo "")
  PAGES_URL=$(printf '%s' "$PAGES_JSON" | python3 -c "import json,sys;print(json.load(sys.stdin).get('html_url',''))" 2>/dev/null || echo "")
  if [ "$CURRENT_BRANCH" = "$PAGES_BRANCH" ]; then
    ok "Pages is enabled on $PAGES_BRANCH -- $PAGES_URL"
  else
    warn "Pages is enabled, but on '$CURRENT_BRANCH' rather than '$PAGES_BRANCH'"
    if confirm "point Pages at $PAGES_BRANCH?"; then
      gh api --method PUT "repos/$REPO/pages" \
        -f "source[branch]=$PAGES_BRANCH" -f "source[path]=/" >/dev/null \
        && ok "Pages now serves $PAGES_BRANCH"
    fi
  fi
else
  warn "Pages is not enabled"
  if confirm "enable Pages on $PAGES_BRANCH?"; then
    if gh api --method POST "repos/$REPO/pages" \
         -f "source[branch]=$PAGES_BRANCH" -f "source[path]=/" >/dev/null 2>&1; then
      ok "Pages enabled on $PAGES_BRANCH"
    else
      warn "could not enable Pages -- the $PAGES_BRANCH branch must exist first"
      info "let the release workflow run once, then re-run this script"
    fi
  fi
fi

# ── summary ───────────────────────────────────────────────────────────────────
step "Where the app will look"

BASE_URL=$(grep -A1 '^updates:' desktop_updater.yaml 2>/dev/null \
  | grep 'baseUrl:' | sed 's/.*baseUrl:[[:space:]]*//' || echo "")
[ -n "$BASE_URL" ] && info "baseUrl (desktop_updater.yaml): $BASE_URL"
info "app-archive: ${BASE_URL}app-archive.json"

echo
if [ "$CHECK_ONLY" -eq 1 ]; then
  printf '%sChecked only -- nothing was changed.%s\n' "$DIM" "$OFF"
else
  printf '%sDone.%s Pin the printed public key in %s and\n' "$BOLD" "$OFF" "$SERVICE_FILE"
  printf 'macos/Runner/DesktopUpdaterHelperPolicy.json, commit %s, then push\n' "$KEY_PROFILE"
  printf 'to main to cut the first signed release.\n'
fi
