#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ "${LOOKINSIDE_SKIP_DEBUG_AUTH:-0}" == "1" ]]; then
	echo "Skipping debug auth server prep (LOOKINSIDE_SKIP_DEBUG_AUTH=1)"
elif "$SCRIPT_DIR/prepare-debug-auth-server.sh"; then
	echo "Prepared debug auth server."
else
	status=$?
	if [[ "${LOOKINSIDE_REQUIRE_DEBUG_AUTH:-0}" == "1" ]]; then
		echo "fatal: debug auth server prep failed and LOOKINSIDE_REQUIRE_DEBUG_AUTH=1" >&2
		exit "$status"
	fi
	echo "warning: debug auth server prep failed (status=$status); continuing host build" >&2
	echo "         set LOOKINSIDE_REQUIRE_DEBUG_AUTH=1 to fail hard, or LOOKINSIDE_SKIP_DEBUG_AUTH=1 to skip." >&2
fi

pkill -x LookInside 2>/dev/null || true
pkill -x lookinside-auth-server 2>/dev/null || true

cd "$PROJECT_DIR"
rm -rf build/derived
xcodebuild \
	-workspace LookInside.xcworkspace \
	-scheme LookInside \
	-configuration Debug \
	-destination 'platform=macOS' \
	-derivedDataPath build/derived \
	-skipMacroValidation \
	-skipPackagePluginValidation \
	CODE_SIGNING_ALLOWED=NO \
	build

open -n "$PROJECT_DIR/build/derived/Build/Products/Debug/LookInside.app"
