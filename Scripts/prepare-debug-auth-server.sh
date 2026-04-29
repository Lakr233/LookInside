#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MONOREPO_DIR="$(cd "$PROJECT_DIR/.." && pwd)"
AUTH_REPO="$MONOREPO_DIR/LookInside-Auth"
WORKSPACE="$AUTH_REPO/LookInsideAuthenticator.xcworkspace"

DEBUG_ROOT="/tmp/lookinside-auth-server-debug"
DERIVED_DATA="$DEBUG_ROOT/derived-data"
LOG="$DEBUG_ROOT/xcodebuild.log"
DEST_DIR="$DEBUG_ROOT/current"
DEST_APP="$DEST_DIR/lookinside-auth-server.app"

if [ ! -d "$AUTH_REPO" ]; then
	echo "LookInside-Auth repo not found at $AUTH_REPO" >&2
	exit 1
fi

mkdir -p "$DEBUG_ROOT" "$DEST_DIR"

if [ ! -d "$WORKSPACE" ]; then
	(cd "$AUTH_REPO" && mise exec -- tuist generate --no-open)
fi

set +e
xcodebuild \
	-workspace "$WORKSPACE" \
	-scheme LookInsideAuthServer \
	-configuration Debug \
	-destination 'platform=macOS' \
	-derivedDataPath "$DERIVED_DATA" \
	-skipMacroValidation \
	-skipPackagePluginValidation \
	CODE_SIGNING_ALLOWED=NO \
	CODE_SIGNING_REQUIRED=NO \
	CODE_SIGN_IDENTITY= \
	ONLY_ACTIVE_ARCH=YES \
	build >"$LOG" 2>&1
build_status=$?
set -e

if [ "$build_status" -ne 0 ]; then
	echo "LookInsideAuthServer Debug build failed. Log: $LOG" >&2
	tail -80 "$LOG" >&2 || true
	exit "$build_status"
fi

built_app="$(find "$DERIVED_DATA/Build/Products" -type d -name 'lookinside-auth-server.app' | head -1)"
if [ -z "$built_app" ]; then
	echo "Built lookinside-auth-server.app was not found under $DERIVED_DATA/Build/Products" >&2
	exit 1
fi

rm -rf "$DEST_APP"
cp -R "$built_app" "$DEST_APP"
chmod +x "$DEST_APP/Contents/MacOS/lookinside-auth-server"
echo "Prepared debug auth server at $DEST_APP"
