#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

REPO="${REPO:-Lakr233/LookInside}"
RULESET_NAME="${RULESET_NAME:-Protect tags}"
ADMIN_BYPASS_ACTOR_ID="${ADMIN_BYPASS_ACTOR_ID:-5}"

usage() {
    cat <<'EOF'
Usage: bash Scripts/configure-tag-protection.sh [options]

Options:
  --repo <owner/name>       Repository to update. Default: Lakr233/LookInside
  --ruleset-name <name>     Ruleset name. Default: Protect tags
  --help, -h                Show this help.
EOF
}

log() {
    echo "==> $*"
}

fail() {
    echo "Error: $*" >&2
    exit 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo)
                REPO="${2:-}"
                shift 2
                ;;
            --ruleset-name)
                RULESET_NAME="${2:-}"
                shift 2
                ;;
            --help|-h)
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

command -v gh >/dev/null 2>&1 || fail "Missing required command: gh"

tmp_json="$(mktemp "${TMPDIR:-/tmp}/lookinside-tag-ruleset.XXXXXX.json")"
trap 'rm -f "$tmp_json"' EXIT

cat > "$tmp_json" <<EOF
{
  "name": "$RULESET_NAME",
  "target": "tag",
  "enforcement": "active",
  "bypass_actors": [
    {
      "actor_id": $ADMIN_BYPASS_ACTOR_ID,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    }
  ],
  "conditions": {
    "ref_name": {
      "include": [
        "~ALL"
      ],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "creation"
    },
    {
      "type": "update"
    },
    {
      "type": "deletion"
    }
  ]
}
EOF

existing_id="$(
    gh api "repos/${REPO}/rulesets" \
        --jq ".[] | select(.name == \"${RULESET_NAME}\") | .id" \
        2>/dev/null || true
)"

if [[ -n "$existing_id" ]]; then
    log "Updating existing tag ruleset ${existing_id}"
    gh api \
        --method PUT \
        -H "Accept: application/vnd.github+json" \
        "repos/${REPO}/rulesets/${existing_id}" \
        --input "$tmp_json" >/dev/null
else
    log "Creating tag ruleset"
    gh api \
        --method POST \
        -H "Accept: application/vnd.github+json" \
        "repos/${REPO}/rulesets" \
        --input "$tmp_json" >/dev/null
fi

log "Current rulesets:"
gh api "repos/${REPO}/rulesets"
