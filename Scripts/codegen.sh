#!/bin/bash
# DTO codegen from Schemas/ — real implementation lands with task P0-05.
# The interface is stable now so CI (P0-02) can wire the drift check early:
#   codegen.sh          regenerate
#   codegen.sh --check  exit non-zero if generated code drifts from Schemas/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for f in "$ROOT/Schemas/xpc-dtos.yml" "$ROOT/Schemas/vault-schema.yml"; do
    [ -f "$f" ] || { echo "codegen: missing schema $f" >&2; exit 1; }
done

# P0-05 implements generation. Until then there is no generated code, so
# both modes succeed after validating the schemas exist.
echo "codegen: schemas present; generation not yet implemented (P0-05)."
exit 0
