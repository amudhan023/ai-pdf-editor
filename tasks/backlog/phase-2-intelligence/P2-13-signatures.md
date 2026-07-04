# P2-13 — Signatures: Create, Store, Place, Flatten

**Epic:** E4 · **Primary package:** `Packages/DocumentSession` (signature feature) · **Complexity:** M · **Priority:** High

## Goal
Signature/initials lifecycle (PRD FR-1.6): create by trackpad, camera (Continuity/ FaceTime capture with background removal), or typed styles; store encrypted in the vault; place/resize on any page; flatten on export.

## Background
Marcus's sign-and-return loop. Stored signatures are vault attachments (Sensitive tier — a signature is identity data), so placement goes through PolicyKit grants like any sensitive read.

## Requirements
- Creation flows: ink canvas (pressure-aware), camera capture with paper-background removal (Vision), typed with 4–5 styles; manage multiple signatures + initials.
- Storage: encrypted attachment via VaultStore, Sensitive tier; grant-gated retrieval.
- Placement: drag from picker, resize with aspect lock, as stamp-like annotation until flatten; flatten = burn into content stream on export/save-as (annotation removed).
- Quick-access picker in toolbar for fill workflows.

## Dependencies
- P1-05 (stamp plumbing), P1-08 (attachments), P0-10.

## Files Likely Affected
- `Packages/DocumentSession/Sources/Signatures/**`; small VaultStore attachment-API use (no schema change).

## Acceptance Criteria
- Sign-a-W-9 flow ≤ 30 seconds from open picker to flattened export; flattened output shows signature in Acrobat/Preview with no annotation object.
- Signature bytes never on disk unencrypted (temp-file audit test).

## Definition of Done
- Global DoD.

## Testing Requirements
- Background-removal snapshot tests; flatten correctness (content-stream inspection); grant-gating test.

## Documentation Updates
- None beyond package CLAUDE.md.
