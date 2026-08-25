#!/bin/bash

set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow_path="$root_dir/.github/workflows/release.yml"

if grep -n $'\t' "$workflow_path" >/dev/null; then
	echo "workflow contains tab indentation" >&2
	exit 1
fi

assert_contains() {
	local needle="$1"
	grep -F -- "$needle" "$workflow_path" >/dev/null
}

assert_absent() {
	local needle="$1"
	if grep -F -- "$needle" "$workflow_path" >/dev/null; then
		echo "unexpected release workflow text: $needle" >&2
		exit 1
	fi
}

assert_contains "parent-app-release"
assert_contains 'run-name: ${{ github.event.client_payload.release_id }}'
assert_contains 'SOURCE_REF="${{ github.event.client_payload.source_ref }}"'
assert_contains 'INJECTOR_REF="${{ github.event.client_payload.injector_ref }}"'
assert_contains 'MCP_REF="${{ github.event.client_payload.mcp_ref }}"'
assert_contains 'RELEASE_REF="${{ github.event.client_payload.release_ref }}"'
assert_contains 'ref: ${{ needs.prepare.outputs.source_ref }}'
assert_contains 'checkout --detach "${{ needs.prepare.outputs.injector_ref }}"'
assert_contains 'checkout --detach "${{ needs.prepare.outputs.mcp_ref }}"'
assert_contains 'token: ${{ secrets.LOOKINSIDE_WEB_RELEASE_TOKEN }}'
assert_contains 'target_commitish: ${{ needs.prepare.outputs.source_ref }}'
assert_contains 'ref: ${{ needs.prepare.outputs.release_ref }}'
assert_contains 'sync-auth-server-assets-to-web.sh'
assert_contains 'public/downloads/auth-server'
assert_absent "workflow_dispatch:"
assert_absent "tags:"

echo "host release workflow tests passed"
