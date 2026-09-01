#!/bin/sh
set -eu

# Host-side tests for reading Xcode-exported .viewhierarchy documents.
#
# Same shape as test-mcp-bridge.sh: compile the unit under test together with
# its test file into a standalone binary and run it. The parsing layer is
# deliberately Foundation-only so it can be covered this way; the pixel
# recovery and conversion layers pull in QuartzCore and the ObjC model and are
# exercised against real captures instead.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}/lookinside-xcode-viewhierarchy-tests.$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

SOURCE_DIR="$ROOT/LookInside/XcodeViewHierarchy"
TEST_DIR="$ROOT/Tests/XcodeViewHierarchy"

# Gzip inflation: response entries are gzip members whose header length varies,
# and whose payload exceeds the inflater's buffer.
swiftc -parse-as-library \
	"$SOURCE_DIR/LKXcodeViewHierarchyGzip.swift" \
	"$TEST_DIR/LKXcodeViewHierarchyGzipTests.swift" \
	-o "$TMPDIR/gzip-test"
"$TMPDIR/gzip-test"

# Property value decoding: the format-specifier scheme, including the
# hexadecimal floats and the per-specifier integer radix.
swiftc -parse-as-library \
	"$SOURCE_DIR/LKXcodeViewHierarchyValue.swift" \
	"$TEST_DIR/LKXcodeViewHierarchyValueTests.swift" \
	-o "$TMPDIR/value-test"
"$TMPDIR/value-test"

# Object graph assembly: merge rules across responses.
swiftc -parse-as-library \
	"$SOURCE_DIR/LKXcodeViewHierarchyValue.swift" \
	"$SOURCE_DIR/LKXcodeViewHierarchyObjectGraph.swift" \
	"$TEST_DIR/LKXcodeViewHierarchyObjectGraphTests.swift" \
	-o "$TMPDIR/object-graph-test"
"$TMPDIR/object-graph-test"

# Pixel recovery: the two-part orientation correction for y-down captures.
swiftc -parse-as-library \
	"$SOURCE_DIR/LKXcodeViewHierarchyValue.swift" \
	"$SOURCE_DIR/LKXcodeViewHierarchyObjectGraph.swift" \
	"$SOURCE_DIR/LKXcodeViewHierarchyLayerArchive.swift" \
	"$SOURCE_DIR/LKXcodeViewHierarchyPixelRecovery.swift" \
	"$TEST_DIR/LKXcodeViewHierarchyPixelRecoveryTests.swift" \
	-o "$TMPDIR/pixel-recovery-test"
"$TMPDIR/pixel-recovery-test"

echo "Xcode view hierarchy tests passed"
