#!/bin/sh

set -eu

LOOKINSIDE_APP="${LOOKINSIDE_APP:-/Users/admin/Desktop/LookInside.app}"
LOOKINSIDE_BIN="${LOOKINSIDE_BIN:-${LOOKINSIDE_APP}/Contents/MacOS/LookInside}"
TARGET_APP_BIN="${TARGET_APP_BIN:-/Users/admin/Desktop/CotEditor-Test.app/Contents/MacOS/CotEditor}"
INJECTED_LIB="${INJECTED_LIB:-/Users/admin/Desktop/libLookinServerInjected.dylib}"
TARGET_BUNDLE_ID="${TARGET_BUNDLE_ID:-com.coteditor.CotEditor}"
SERVER_LOG="${SERVER_LOG:-/Users/admin/Desktop/coteditor-lookinside.log}"

pkill -f "${LOOKINSIDE_BIN}" || true
pkill -f "${TARGET_APP_BIN}" || true
sleep 1

nohup env DYLD_INSERT_LIBRARIES="${INJECTED_LIB}" "${TARGET_APP_BIN}" >"${SERVER_LOG}" 2>&1 </dev/null &
sleep 2

lsof -nP -iTCP -sTCP:LISTEN | egrep "4717|CotEditor" || true

nohup env LOOKINSIDE_AUTO_CONNECT_BUNDLE_ID="${TARGET_BUNDLE_ID}" "${LOOKINSIDE_BIN}" >/Users/admin/Desktop/lookinside-live.log 2>&1 </dev/null &
sleep 3

pgrep -af "CotEditor|LookInside"
