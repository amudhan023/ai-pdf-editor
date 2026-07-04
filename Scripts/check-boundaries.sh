#!/bin/bash
# Import-boundary lint. Enforces the per-package allowlist in
# Scripts/import-allowlist.txt (see docs/REPO_STRUCTURE.md §3).
#
# Usage:
#   Scripts/check-boundaries.sh <Package>    check one package
#   Scripts/check-boundaries.sh --all        check every package
#   Scripts/check-boundaries.sh --self-test  prove the checker fails on a violation
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ALLOWLIST="$ROOT/Scripts/import-allowlist.txt"
# Imports every target may use without declaration.
UNIVERSAL="Foundation Swift"

allowed_for() {
    grep -E "^$1:" "$ALLOWLIST" | sed "s/^$1://" || true
}

check_package() {
    local pkg="$1" fail=0
    local src="$ROOT/Packages/$pkg/Sources"
    local allowed="$UNIVERSAL $(allowed_for "$pkg") $pkg"
    [ -d "$src" ] || { echo "check-boundaries: no such package '$pkg'" >&2; return 2; }

    while IFS=: read -r file _ imp; do
        imp="$(echo "$imp" | tr -d ' ')"
        local ok=0
        for a in $allowed; do [ "$imp" = "$a" ] && ok=1 && break; done
        if [ "$ok" -eq 0 ]; then
            echo "BOUNDARY VIOLATION: $pkg imports '$imp' ($file)" >&2
            echo "  Allowed: $allowed" >&2
            echo "  Cross-package deps go through *API packages; new deps need an ADR (CLAUDE.md §3.7)." >&2
            fail=1
        fi
    done < <(grep -rnE '^[[:space:]]*(@testable[[:space:]]+)?import[[:space:]]+[A-Za-z_]+' "$src" \
             | sed -E 's/^([^:]+):([0-9]+):[[:space:]]*(@testable[[:space:]]+)?import[[:space:]]+([A-Za-z_]+).*/\1:\2:\4/')

    # Tests: same allowlist plus XCTest.
    local tests="$ROOT/Packages/$pkg/Tests"
    if [ -d "$tests" ]; then
        local tallowed="$allowed XCTest Testing"
        while IFS=: read -r file _ imp; do
            imp="$(echo "$imp" | tr -d ' ')"
            local ok=0
            for a in $tallowed; do [ "$imp" = "$a" ] && ok=1 && break; done
            if [ "$ok" -eq 0 ]; then
                echo "BOUNDARY VIOLATION (tests): $pkg tests import '$imp' ($file)" >&2
                fail=1
            fi
        done < <(grep -rnE '^[[:space:]]*(@testable[[:space:]]+)?import[[:space:]]+[A-Za-z_]+' "$tests" \
                 | sed -E 's/^([^:]+):([0-9]+):[[:space:]]*(@testable[[:space:]]+)?import[[:space:]]+([A-Za-z_]+).*/\1:\2:\4/')
    fi
    return $fail
}

case "${1:-}" in
    --all)
        rc=0
        for d in "$ROOT"/Packages/*/; do
            check_package "$(basename "$d")" || rc=1
        done
        [ $rc -eq 0 ] && echo "check-boundaries: all packages clean."
        exit $rc
        ;;
    --self-test)
        # Plant an illegal import in a temp copy of PolicyKit and require failure.
        tmp="$(mktemp -d)"
        trap 'rm -rf "$tmp"' EXIT
        cp -R "$ROOT/Packages/PolicyKit" "$tmp/PolicyKit"
        echo "import AutofillEngine" > "$tmp/PolicyKit/Sources/PolicyKit/Violation.swift"
        if (ROOT="$tmp" ; src="$tmp/PolicyKit/Sources"
            grep -rqE '^import AutofillEngine' "$src") ; then
            # Re-run real checker against a planted violation inside the repo copy:
            cp "$tmp/PolicyKit/Sources/PolicyKit/Violation.swift" "$ROOT/Packages/PolicyKit/Sources/PolicyKit/.selftest-violation.swift"
            trap 'rm -f "$ROOT/Packages/PolicyKit/Sources/PolicyKit/.selftest-violation.swift"; rm -rf "$tmp"' EXIT
            if check_package PolicyKit 2>/dev/null; then
                echo "SELF-TEST FAILED: planted violation was NOT detected." >&2
                exit 1
            else
                echo "check-boundaries: self-test passed (planted violation detected)."
                exit 0
            fi
        fi
        ;;
    "")
        echo "usage: check-boundaries.sh <Package> | --all | --self-test" >&2
        exit 2
        ;;
    *)
        check_package "$1" && echo "check-boundaries: $1 clean."
        ;;
esac
