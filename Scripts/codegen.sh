#!/bin/bash
# DTO codegen from Schemas/xpc-dtos.yml -> Packages/Platform/Sources/Platform/
# XPC/Generated/XPCDTOs.generated.swift. Parsing logic lives in
# Scripts/_xpc_codegen.py (a hand-written parser for the constrained schema
# grammar in Schemas/README.md, not general YAML).
#
#   codegen.sh          regenerate the committed file
#   codegen.sh --check  exit non-zero if the committed file drifts from
#                       what Schemas/xpc-dtos.yml would generate (CI drift gate)
#
# vault-schema.yml has no generator yet (P0-09/P1-08 own that); this script
# only validates it exists so both schemas stay checked for presence.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA="$ROOT/Schemas/xpc-dtos.yml"
GENERATED="$ROOT/Packages/Platform/Sources/Platform/XPC/Generated/XPCDTOs.generated.swift"

for f in "$SCHEMA" "$ROOT/Schemas/vault-schema.yml"; do
    [ -f "$f" ] || { echo "codegen: missing schema $f" >&2; exit 1; }
done

case "${1:-}" in
    --check)
        tmp="$(mktemp)"
        trap 'rm -f "$tmp"' EXIT
        python3 "$ROOT/Scripts/_xpc_codegen.py" "$SCHEMA" > "$tmp"
        if [ ! -f "$GENERATED" ]; then
            echo "codegen: $GENERATED does not exist - run 'Scripts/codegen.sh' and commit it." >&2
            exit 1
        fi
        if ! diff -u "$GENERATED" "$tmp"; then
            echo "codegen: generated DTOs are out of sync with $SCHEMA - run 'Scripts/codegen.sh' and commit the diff." >&2
            exit 1
        fi
        echo "codegen: up to date."
        ;;
    "")
        mkdir -p "$(dirname "$GENERATED")"
        python3 "$ROOT/Scripts/_xpc_codegen.py" "$SCHEMA" > "$GENERATED"
        echo "codegen: regenerated $GENERATED"
        ;;
    *)
        echo "usage: codegen.sh [--check]" >&2
        exit 2
        ;;
esac
