#!/bin/bash
# Per-package verification: build + tests + import-boundary lint.
# This is the same command CI runs — green here means green there.
#
# Verdicts are exit-code based. Tool output is shown only on failure
# (note: Command Line Tools installs emit cosmetic SwiftPM manifest linker
# noise on stderr even on success — exit codes are the truth, not the log).
#
# Usage:
#   Scripts/verify.sh <Package>   verify one package
#   Scripts/verify.sh --all       verify every package (sequential)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

run_step() {  # run_step <pkg> <label> <cmd...>
    local pkg="$1" label="$2"; shift 2
    if ! "$@" >"$LOG" 2>&1; then
        echo "==> $pkg: $label FAILED"
        tail -30 "$LOG"
        return 1
    fi
    return 0
}

verify_one() {
    local pkg="$1"
    local dir="$ROOT/Packages/$pkg"
    if [ ! -d "$dir" ]; then echo "verify: no such package '$pkg'" >&2; return 2; fi
    run_step "$pkg" "build"      swift build --package-path "$dir" -q            || return 1
    run_step "$pkg" "test"       swift test  --package-path "$dir" -q            || return 1
    run_step "$pkg" "boundaries" "$ROOT/Scripts/check-boundaries.sh" "$pkg"      || return 1
    echo "==> $pkg: OK"
    return 0
}

case "${1:-}" in
    --all)
        rc=0
        for d in "$ROOT"/Packages/*/; do
            verify_one "$(basename "$d")"
            [ $? -ne 0 ] && rc=1
        done
        if [ $rc -eq 0 ]; then echo "verify: ALL PACKAGES OK"; else echo "verify: FAILURES (see above)"; fi
        exit $rc
        ;;
    "")
        echo "usage: verify.sh <Package> | --all" >&2
        exit 2
        ;;
    *)
        verify_one "$1"
        exit $?
        ;;
esac
