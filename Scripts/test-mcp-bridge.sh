#!/bin/sh
set -eu

# Host-side MCPBridge tests.
#
# Same shape as test-security-gates.sh: compile the unit under test
# together with its test file into a standalone binary and run it. Only
# units that depend on Darwin / Foundation alone can be covered this
# way -- the routing services pull in AppKit, NSDocumentController and
# the ObjC bridge, so they are exercised through the end-to-end smoke
# test in docs/monorepo/mcp-smoke-test.md instead.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}/lookinside-mcp-bridge-tests.$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

LISTEN_SOCKET="$ROOT/LookInside/MCPBridge/LKMCPBridgeListenSocket.swift"
LISTEN_SOCKET_TEST="$ROOT/Tests/MCPBridge/LKMCPBridgeListenSocketTests.swift"

swiftc -parse-as-library "$LISTEN_SOCKET" "$LISTEN_SOCKET_TEST" -o "$TMPDIR/listen-socket-test"
"$TMPDIR/listen-socket-test"

SEARCH_QUERY="$ROOT/LookInside/MCPBridge/LKMCPBridgeSearchQuery.swift"
SEARCH_QUERY_TEST="$ROOT/Tests/MCPBridge/LKMCPBridgeSearchQueryTests.swift"

swiftc -parse-as-library "$SEARCH_QUERY" "$SEARCH_QUERY_TEST" -o "$TMPDIR/search-query-test"
"$TMPDIR/search-query-test"

# The identifier list needs LKMCPBridgeFrame.swift alongside it for
# LKMCPBridgeJSONValue; that file is Foundation-only, so it compiles here.
FRAME="$ROOT/LookInside/MCPBridge/LKMCPBridgeFrame.swift"
OBJECT_IDENTIFIER_LIST="$ROOT/LookInside/MCPBridge/LKMCPBridgeObjectIdentifierList.swift"
OBJECT_IDENTIFIER_LIST_TEST="$ROOT/Tests/MCPBridge/LKMCPBridgeObjectIdentifierListTests.swift"

swiftc -parse-as-library "$FRAME" "$OBJECT_IDENTIFIER_LIST" "$OBJECT_IDENTIFIER_LIST_TEST" -o "$TMPDIR/object-identifier-list-test"
"$TMPDIR/object-identifier-list-test"

# Catch-clause ordering guard.
#
# `catch let error as NSError` matches *every* Swift error -- they all bridge
# to NSError -- so above the RACBridgeError clauses it swallows them and makes
# them dead code, silently degrading precise error codes into internalError.
# The routes cannot be unit-tested here (AppKit + the ObjC bridge come along),
# so this is a textual guard on a mistake that is easy to repeat every time a
# new route is added by copying an existing one.
ordering_failures=0
for service in "$ROOT"/LookInside/MCPBridge/LKMCPBridge*Service.swift; do
	nserror_line=$(grep -n "catch let error as NSError" "$service" | head -1 | cut -d: -f1)
	racbridge_line=$(grep -n "catch RACBridgeError" "$service" | head -1 | cut -d: -f1)
	if [ -n "$nserror_line" ] && [ -n "$racbridge_line" ] && [ "$nserror_line" -lt "$racbridge_line" ]; then
		echo "FAIL: $(basename "$service"): 'catch let error as NSError' on line $nserror_line precedes 'catch RACBridgeError' on line $racbridge_line, which makes the RACBridgeError clauses unreachable" >&2
		ordering_failures=$((ordering_failures + 1))
	fi
done
if [ "$ordering_failures" -ne 0 ]; then
	exit 1
fi
echo "MCPBridge catch ordering guard passed"

echo "MCPBridge tests passed"
