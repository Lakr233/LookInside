#!/bin/sh

set -eu

LOOKINSIDE_BIN="${LOOKINSIDE_BIN:-/Users/admin/Desktop/lookinside}"
SERVER_LOG="${SERVER_LOG:-/Users/admin/Desktop/coteditor-lookinside.log}"
OUT_ROOT="${OUT_ROOT:-/Users/admin/Desktop/lookinside-probe}"
TRANSPORT="${TRANSPORT:-mac}"
KILL_LOOKINSIDE="${KILL_LOOKINSIDE:-1}"

timestamp="$(date +%Y%m%d-%H%M%S)"
run_dir="${OUT_ROOT}/${timestamp}"
mkdir -p "$run_dir"

note() {
    printf '%s\n' "$*" | tee -a "$run_dir/summary.txt"
}

run_and_capture() {
    name="$1"
    shift
    note ""
    note "## ${name}"
    note "$*"
    if "$@" >"$run_dir/${name}.out" 2>"$run_dir/${name}.err"; then
        cat "$run_dir/${name}.out" | tee -a "$run_dir/summary.txt"
        return 0
    fi
    cat "$run_dir/${name}.out" | tee -a "$run_dir/summary.txt"
    cat "$run_dir/${name}.err" | tee -a "$run_dir/summary.txt"
    return 1
}

find_target() {
    attempt=1
    while [ "$attempt" -le 8 ]; do
        target="$("$LOOKINSIDE_BIN" list --transport "$TRANSPORT" --ids-only 2>/dev/null | head -n 1 || true)"
        case "$target" in
            *:*)
                printf '%s' "$target"
                return 0
                ;;
        esac
        sleep 1
        attempt=$((attempt + 1))
    done
    return 1
}

note "# LookInside VM Probe"
note "run_dir=$run_dir"
note "lookinside=$LOOKINSIDE_BIN"
note "kill_lookinside=$KILL_LOOKINSIDE"

if [ "$KILL_LOOKINSIDE" = "1" ]; then
    run_and_capture kill_lookinside sh -lc "pkill -f '/Users/admin/Desktop/LookInside.app/Contents/MacOS/LookInside' || true" || true
    sleep 1
fi

run_and_capture ps pgrep -af "CotEditor|LookInside" || true
run_and_capture listeners sh -lc "lsof -nP -iTCP -sTCP:LISTEN | egrep '4717|CotEditor' || true" || true
run_and_capture list_json "$LOOKINSIDE_BIN" list --format json || true

target="$(find_target || true)"
note "target=${target:-<none>}"

if [ -n "${target:-}" ]; then
    run_and_capture inspect_json "$LOOKINSIDE_BIN" inspect --target "$target" --format json || true
    sleep 1
    run_and_capture hierarchy_json "$LOOKINSIDE_BIN" hierarchy --target "$target" --format json || true
    sleep 1
    export_path="$run_dir/target.lookinside"
    if run_and_capture export_archive "$LOOKINSIDE_BIN" export --target "$target" --output "$export_path"; then
        run_and_capture export_ls ls -lh "$export_path" || true
    fi
fi

run_and_capture server_log_tail tail -n 200 "$SERVER_LOG" || true

note ""
note "Probe complete."
note "$run_dir"
