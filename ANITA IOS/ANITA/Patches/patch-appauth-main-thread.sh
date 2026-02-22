#!/bin/bash
# Patch AppAuth OIDExternalUserAgentIOS.m so presentationAnchor runs on main thread (Main Thread Checker).
# Runs as an Xcode Run Script phase before Compile Sources.
# Arg 1: DERIVED_FILE_DIR (optional) - if set, touch .../appauth-patch.stamp for build phase output.
# Do not use set -e so we always exit 0 and never fail the build.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="${SCRIPT_DIR}/AppAuth-main-thread.patch"
STAMP_DIR="${1:-}"

# Find AppAuth-iOS checkout (SPM puts it in DerivedData or next to project)
ROOT="${SRCROOT:-.}"
APPATH_IOS=""
for base in "${ROOT}/../SourcePackages/checkouts" "${BUILD_DIR%/*/*}/SourcePackages/checkouts" "${ROOT}/SourcePackages/checkouts"; do
  if [ -d "${base}/AppAuth-iOS" ]; then
    APPATH_IOS="${base}/AppAuth-iOS"
    break
  fi
done
if [ -z "$APPATH_IOS" ]; then
  # Fallback: find by filename
  APPATH_IOS="$(find "${ROOT}" -type d -name "AppAuth-iOS" 2>/dev/null | head -1)"
fi
if [ -z "$APPATH_IOS" ] || [ ! -d "$APPATH_IOS" ]; then
  echo "note: AppAuth-iOS checkout not found, skipping main-thread patch"
  [ -n "$STAMP_DIR" ] && touch "${STAMP_DIR}/appauth-patch.stamp" 2>/dev/null || true
  exit 0
fi

TARGET="${APPATH_IOS}/Sources/AppAuth/iOS/OIDExternalUserAgentIOS.m"
if [ ! -f "$TARGET" ]; then
  echo "note: OIDExternalUserAgentIOS.m not found at ${TARGET}, skipping"
  [ -n "$STAMP_DIR" ] && touch "${STAMP_DIR}/appauth-patch.stamp" 2>/dev/null || true
  exit 0
fi

if grep -q "NSThread isMainThread" "$TARGET" 2>/dev/null; then
  [ -n "$STAMP_DIR" ] && touch "${STAMP_DIR}/appauth-patch.stamp" 2>/dev/null || true
  exit 0
fi

if [ ! -f "$PATCH_FILE" ]; then
  echo "warning: Patch file not found: $PATCH_FILE"
  [ -n "$STAMP_DIR" ] && touch "${STAMP_DIR}/appauth-patch.stamp" 2>/dev/null || true
  exit 0
fi

cd "$APPATH_IOS" || { [ -n "$STAMP_DIR" ] && touch "${STAMP_DIR}/appauth-patch.stamp" 2>/dev/null; exit 0; }
if patch -p0 --forward -r - < "$PATCH_FILE" 2>/dev/null; then
  echo "Applied AppAuth main-thread patch to OIDExternalUserAgentIOS.m"
else
  echo "note: AppAuth patch not applied (maybe already applied or file changed)"
fi
[ -n "$STAMP_DIR" ] && touch "${STAMP_DIR}/appauth-patch.stamp" 2>/dev/null || true
exit 0
