#!/bin/bash

set -euo pipefail

SPARKLE_VERSION="${SPARKLE_VERSION:-2.9.1}"
OUTPUT_DIR="${OUTPUT_DIR:-${RUNNER_TEMP:-/tmp}/sparkle-tools-${SPARKLE_VERSION}}"

usage() {
	cat <<'EOF'
Usage: bash Scripts/install-sparkle-tools.sh [options]

Options:
  --version <version>     Sparkle release version. Default: SPARKLE_VERSION or 2.9.1.
  --output-dir <path>     Directory where the Sparkle distribution is extracted.
                          Default: RUNNER_TEMP/sparkle-tools-<version>.
  --help, -h              Show this help.
EOF
}

fail() {
	echo "Error: $*" >&2
	exit 1
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--version)
			SPARKLE_VERSION="${2:-}"
			shift 2
			;;
		--output-dir)
			OUTPUT_DIR="${2:-}"
			shift 2
			;;
		--help | -h)
			usage
			exit 0
			;;
		*)
			fail "Unknown option: $1"
			;;
		esac
	done
}

parse_args "$@"

[[ -n "$SPARKLE_VERSION" ]] || fail "--version is required."
[[ -n "$OUTPUT_DIR" ]] || fail "--output-dir is required."

tool_path="$OUTPUT_DIR/bin/generate_appcast"
if [[ -x "$tool_path" ]]; then
	echo "$OUTPUT_DIR"
	exit 0
fi

archive_path="${RUNNER_TEMP:-/tmp}/Sparkle-${SPARKLE_VERSION}.tar.xz"
download_url="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

curl -fsSL "$download_url" -o "$archive_path"
tar -xJf "$archive_path" -C "$OUTPUT_DIR"

[[ -x "$tool_path" ]] || fail "generate_appcast not found after extracting Sparkle ${SPARKLE_VERSION}."

echo "$OUTPUT_DIR"
