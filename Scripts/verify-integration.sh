#!/bin/bash
# Per-package integration-tier verification: runs only the *Conformance/
# *Integration test classes within a package's existing test target — a
# labeled subset of what Scripts/verify.sh's "test" step already runs, not
# a second test target. See CLAUDE.md §9 for the naming convention: any
# `final class *ConformanceTests: XCTestCase` or `*IntegrationTests` is
# picked up here automatically, no CI edit needed.
#
# A package with no matching test class is a legitimate "nothing to run
# yet" skip, not a failure — most packages are still bootstrap skeletons
# (P0-15).
#
# Usage:
#   Scripts/verify-integration.sh <Package>   run one package's integration tier
#   Scripts/verify-integration.sh --all       run every package's integration tier
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

FILTER='(Conformance|Integration)Tests'

has_integration_tests() {
    local dir="$1"
    [ -d "$dir/Tests" ] && grep -rlE "final class .*($FILTER)\s*:\s*XCTestCase" "$dir/Tests" >/dev/null 2>&1
}

verify_one() {
    local pkg="$1"
    local dir="$ROOT/Packages/$pkg"
    if [ ! -d "$dir" ]; then echo "verify-integration: no such package '$pkg'" >&2; return 2; fi
    if ! has_integration_tests "$dir"; then
        echo "==> $pkg: no integration-tier tests yet, skipping"
        return 0
    fi
    if ! swift test --package-path "$dir" --filter "$FILTER" -q >"$LOG" 2>&1; then
        echo "==> $pkg: integration tests FAILED"
        tail -30 "$LOG"
        return 1
    fi
    echo "==> $pkg: integration tests OK"
    return 0
}

# TODO(P1-16): once Scripts/corpus-roundtrip.sh exists (open->mutate->save->
# reopen across the fixture corpus), invoke it here too, gated on whether
# the touched packages include a mutation-path one (CLAUDE.md §11).

case "${1:-}" in
    --all)
        rc=0
        for d in "$ROOT"/Packages/*/; do
            verify_one "$(basename "$d")"
            [ $? -ne 0 ] && rc=1
        done
        if [ $rc -eq 0 ]; then echo "verify-integration: ALL PACKAGES OK"; else echo "verify-integration: FAILURES (see above)"; fi
        exit $rc
        ;;
    "")
        echo "usage: verify-integration.sh <Package> | --all" >&2
        exit 2
        ;;
    *)
        verify_one "$1"
        exit $?
        ;;
esac
