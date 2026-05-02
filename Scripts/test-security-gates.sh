#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}/lookinside-security-tests.$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

POLICY="$ROOT/LookInside/SwiftUISupport/LKSwiftUISupportAuthServerPathPolicy.swift"
TEST="$ROOT/Tests/Security/LKSwiftUISupportAuthServerPathPolicyTests.swift"

swiftc -parse-as-library "$POLICY" "$TEST" -o "$TMPDIR/path-policy-release"
"$TMPDIR/path-policy-release"

swiftc -D DEBUG -parse-as-library "$POLICY" "$TEST" -o "$TMPDIR/path-policy-debug"
"$TMPDIR/path-policy-debug"

echo "Security gate tests passed"
