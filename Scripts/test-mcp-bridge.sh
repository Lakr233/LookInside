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

echo "MCPBridge tests passed"
