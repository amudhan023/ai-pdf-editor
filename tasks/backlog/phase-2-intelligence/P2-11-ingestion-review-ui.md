# P2-11 — Ingestion Review UI & Conflict Resolution

**Epic:** E13 · **Primary package:** `Packages/IngestionSession` · **Complexity:** L · **Priority:** High

## Goal
The mandatory review flow (PRD FR-3.4/3.5): candidates side-by-side with source-image snippets, accept/edit/reject per field, conflict resolution (replace / keep-both-as-history / discard), transactional commit to the vault.

## Background
ARCHITECTURE.md §5.1 sequence: nothing enters the vault unconfirmed; accepted set commits as one transaction (P1-10 batch write). Conflicts use compare-read (values summarized, not exposed pre-grant).

## Requirements
- IngestionSession state machine (queued → processing → reviewing → committing); drag-drop + picker entry points; progress during pipeline run.
- Review UI: candidate rows with cropped source snippet (region provenance), editable value, target vault path (changeable via searchable path picker), confidence chip.
- Conflict rows: current-vs-new presentation, replace/keep-both/discard actions; keep-both routes to history entries where the path is history-typed.
- Attachment opt-in toggle ("keep original document in vault") per FR-2.7; per-ingestion ephemeral mode stub (full feature H1, but no-persist path must exist now).
- Commit via PolicyKit grant; `IngestionCommitted` audit event.

## Dependencies
- P2-08, P2-09 or P2-10 (at least one real extractor), P1-10, P1-11 (path picker reuse).

## Files Likely Affected
- `Packages/IngestionSession/Sources/**`.

## Acceptance Criteria
- M4 script: drop synthetic passport → review with snippets → commit → fields visible in Vault Manager with provenance, ≤ 2 minutes.
- Rejecting all candidates leaves vault byte-identical (verified).

## Definition of Done
- Global DoD, plus: M4 demo script docs/specs/m4-demo.md.

## Testing Requirements
- State-machine tests; conflict-path tests incl. history routing; transactional commit/rollback tests; snapshot tests.

## Documentation Updates
- Package `CLAUDE.md`.
