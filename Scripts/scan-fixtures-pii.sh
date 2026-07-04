#!/bin/bash
# PII + secret pattern scan over Fixtures/ (see CLAUDE.md §6, Constitution
# Article 15: fixtures are synthetic-only, real personal data never enters
# the repo). This is a shape/pattern scan, not a semantic one — it exists to
# catch the class of mistake ("pasted a real-looking value into a fixture"),
# not to certify a fixture is actually synthetic.
#
# Usage:
#   Scripts/scan-fixtures-pii.sh             scan Fixtures/
#   Scripts/scan-fixtures-pii.sh --self-test  prove the scanner fails on a planted pattern
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/Fixtures"

# name:regex — one per PII/secret shape. Plain POSIX ERE only (grep -E) —
# no \b, no PCRE syntax — so this behaves identically under BSD grep (macOS
# CI runners, this repo's dev machines) and GNU grep.
PATTERNS='
SSN:[0-9]{3}-[0-9]{2}-[0-9]{4}
CREDIT_CARD:[0-9]{4}[ -]?[0-9]{4}[ -]?[0-9]{4}[ -]?[0-9]{4}
AWS_ACCESS_KEY:AKIA[0-9A-Z]{16}
PRIVATE_KEY_BLOCK:-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----
'

scan_dir() {
    local dir="$1" fail=0
    [ -d "$dir" ] || { echo "scan-fixtures-pii: no such directory '$dir'" >&2; return 2; }

    while IFS=: read -r name pattern; do
        [ -z "$name" ] && continue
        while IFS= read -r hit; do
            [ -z "$hit" ] && continue
            echo "PII/SECRET PATTERN ($name): $hit" >&2
            fail=1
        done < <(grep -rlIE "$pattern" "$dir" 2>/dev/null || true)
    done <<< "$PATTERNS"

    if [ "$fail" -eq 0 ]; then
        echo "scan-fixtures-pii: clean (no PII/secret-shaped patterns found)."
    else
        echo "Fixtures must contain synthetic data only (CLAUDE.md §6, Constitution Art. 15)." >&2
        echo "Replace the flagged value(s) with an obviously-fake equivalent." >&2
    fi
    return $fail
}

case "${1:-}" in
    --self-test)
        tmp="$(mktemp -d)"
        trap 'rm -rf "$tmp"' EXIT
        echo "planted fake value: 123-45-6789" > "$tmp/planted.txt"
        if scan_dir "$tmp" >/dev/null 2>&1; then
            echo "SELF-TEST FAILED: planted SSN-shaped pattern was NOT detected." >&2
            exit 1
        else
            echo "scan-fixtures-pii: self-test passed (planted pattern detected)."
            exit 0
        fi
        ;;
    "")
        scan_dir "$FIXTURES"
        ;;
    *)
        echo "usage: scan-fixtures-pii.sh | --self-test" >&2
        exit 2
        ;;
esac
