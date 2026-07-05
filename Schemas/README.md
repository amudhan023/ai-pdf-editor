# Schemas/

Single source of truth for cross-process/cross-boundary types. Both files here are **frozen seams** (root `CLAUDE.md` §3.6): changing them requires an ADR + `[INTEGRATION]`-marked PR.

## `xpc-dtos.yml`

Feeds `Scripts/codegen.sh`, which generates `Packages/Platform/Sources/Platform/XPC/Generated/XPCDTOs.generated.swift`. Never hand-edit the generated file — `Scripts/codegen.sh --check` (wired into CI) fails the build if it's out of sync with this schema.

**Grammar** (a deliberately constrained subset of YAML — not general YAML; `Scripts/_xpc_codegen.py` hand-parses exactly this shape, no more):

```yaml
version: 1              # schema format version, bump on breaking grammar changes
interfaceVersion: v1    # XPC interface version string (ARCHITECTURE.md §3.3 versioning convention)
dtos:
  <DTOName>:
    fields:
      <fieldName>: <type>
```

- 2-space indentation, exactly as shown. No lists, no inline maps (except the empty `{}` placeholder), no quoting, no anchors/aliases, no multi-document files.
- Supported `<type>` values: `string` (`String`), `int` (`Int`), `bool` (`Bool`), `date` (`Date`), `data` (`Data`). Extending this list is a codegen change, not a schema change — update `Scripts/_xpc_codegen.py`'s `TYPE_MAP` and this doc together.
- Every DTO generates a `public struct <DTOName>: Codable, Sendable` with one `let` per field, in declaration order, plus a memberwise `public init`.

## `vault-schema.yml`

Populated by P0-09/P1-08 — see that schema's own header comment for its (still TODO) grammar.
