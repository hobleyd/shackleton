#!/bin/sh
#
# Builds, signs and embeds desktop_updater's privileged install helper into the
# app bundle. Run as an Xcode build phase on the Runner target.
#
# Without it `Contents/Helpers/DesktopUpdaterInstallHelper` does not exist, and
# the in-app updater fails at the very last step: the native side reads the
# sealed release-key policy out of that binary's signature before it will
# accept a staged update, so an update downloads and verifies and then reports
# "Unable to prepare update installation" with no detail.
#
# This is a thin wrapper around the package's own embed_install_helper.sh. It
# exists to do the three things that script leaves to the host project:
#
#   * find the package, wherever pub put it;
#   * derive DESKTOP_UPDATER_SEALED_POLICY_SHA256 from the policy file instead
#     of carrying a copy of the digest in project.pbxproj, where the two would
#     silently drift the first time somebody edited the policy;
#   * stay out of the way of debug builds.

set -eu

fail() {
  echo "error: embed_update_helper: $*" >&2
  exit 1
}

# Release only. The helper is what *installs* an update, and nothing installs
# one from a `flutter run` build -- while a per-architecture `swift build` on
# every debug build is a large tax on the edit loop. It also keeps the
# helper's signature matched to one policy: an ad-hoc signed debug build
# cannot satisfy the Developer ID requirement the sealed policy names, so a
# debug build that embedded a helper would need a second policy to go with
# it.
if [ "${CONFIGURATION:-}" != "Release" ]; then
  echo "embed_update_helper: skipping in ${CONFIGURATION:-unknown} configuration"
  exit 0
fi

# An ad-hoc or unsigned build gets no helper. The sealed policy names a
# Developer ID designated requirement, so the package's own layout check
# would refuse the helper it had just signed and fail the build -- and a
# fork PR, or anyone building release locally without the certificate, is
# meant to keep building exactly as it did before. Such a build cannot
# install an in-app update regardless: staging verifies the downloaded app
# against the *running* app's team identifier.
identity=${EXPANDED_CODE_SIGN_IDENTITY:-${CODE_SIGN_IDENTITY:-}}
case "$identity" in
  "" | "-")
    echo "embed_update_helper: skipping, this build is not signed with an identity"
    exit 0
    ;;
esac

project_dir=${PROJECT_DIR:?PROJECT_DIR is required}
policy="$project_dir/Runner/DesktopUpdaterHelperPolicy.json"
[ -f "$policy" ] || fail "sealed policy is missing: $policy"

# The CocoaPods symlink farm is the stable way to the package from inside a
# build: it is rebuilt from pubspec on every `flutter pub get`, so it follows
# a version bump without this path being touched.
helper_dir="$project_dir/Flutter/ephemeral/.symlinks/plugins/desktop_updater/macos/install_helper"
if [ ! -d "$helper_dir" ]; then
  # Fall back to whatever package_config.json resolved, for a build that has
  # not gone through pod install.
  root=$(/usr/bin/sed -n 's/.*"name":"desktop_updater","rootUri":"\([^"]*\)".*/\1/p' \
    "$project_dir/../.dart_tool/package_config.json" 2>/dev/null | /usr/bin/head -1)
  case "$root" in
    file://*) helper_dir="${root#file://}/macos/install_helper" ;;
  esac
fi
[ -d "$helper_dir" ] || fail "cannot locate desktop_updater's install_helper; run flutter pub get"

# The digest the package script checks against, and the digest the *app*
# checks at install time, are computed differently: the script hashes the
# file with one trailing newline stripped, while DesktopUpdaterPlugin
# re-serialises the JSON through JSONSerialization with sorted keys and
# hashes that. They agree only while the file is already in that canonical
# form -- compact, keys sorted -- so a reformatted policy would sail through
# the build and fail on the user's machine with nothing to point at. Check it
# here, where it is cheap to say so.
if [ -x /usr/bin/python3 ]; then
  /usr/bin/python3 - "$policy" <<'PY' || fail "DesktopUpdaterHelperPolicy.json is not canonical JSON; re-emit it with sorted keys and no whitespace"
import json, sys
raw = open(sys.argv[1], encoding="utf-8").read()
if raw.endswith("\n"):
    raw = raw[:-1]
canonical = json.dumps(
    json.loads(raw), sort_keys=True, separators=(",", ":"), ensure_ascii=False
)
sys.exit(0 if raw == canonical else 1)
PY
fi

policy_sha256=$(/usr/bin/perl -0pe 's/\r?\n\z//' "$policy" |
  /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}')
[ -n "$policy_sha256" ] || fail "could not digest $policy"

DESKTOP_UPDATER_HELPER_INFO_TEMPLATE="$helper_dir/Configuration/Helper-Info.plist" \
DESKTOP_UPDATER_SEALED_POLICY_PATH="$policy" \
DESKTOP_UPDATER_SEALED_POLICY_SHA256="$policy_sha256" \
  "$helper_dir/embed_install_helper.sh"
