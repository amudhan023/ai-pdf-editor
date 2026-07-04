# P3-05 — Licensing, Free Tier & Purchase Flow

**Epic:** E16 · **Primary package:** `Packages/Platform` (licensing) + gating touches `[INTEGRATION]` · **Complexity:** L · **Priority:** High

## Goal
Monetization per PRD §8: free tier (full viewer/annotations/basic pages, 1 profile limited fields, 3 autofills/month), Pro unlock via MAS StoreKit and direct-channel license keys, offline-tolerant validation.

## Background
Two distribution channels (R11) need one entitlement abstraction. License validation is one of the two enumerated network calls — it must be toggle-visible in the Privacy Dashboard, work offline for long stretches (grace, not dark patterns), and never touch document/vault data.

## Requirements
- `Entitlements` service: feature-flag surface (`proEditor`, `unlimitedVault`, `unlimitedFills`) consumed via injection everywhere gating occurs; single source of truth.
- MAS path: StoreKit 2 one-time purchase + optional subscription (both → identical entitlements); restore purchases.
- Direct path: signed offline-verifiable license keys (Ed25519), activation-count check with long offline grace.
- Free-tier limits: monthly autofill counter (local, resets monthly), profile/field caps — enforced in coordinators, gracious upgrade prompts (no data hostage: viewing existing vault data never gated).
- Purchase/upgrade UI; receipt/license state in Privacy Dashboard network ledger.

## Dependencies
- P2-05 (fill counter hook); coordinates with `App/` (serialize with other App tasks).

## Files Likely Affected
- `Packages/Platform/Sources/Entitlements/**`; gating call sites in session coordinators; `App/` purchase UI.

## Acceptance Criteria
- Both channels unlock identical features (matrix test); 4th monthly autofill on free tier prompts upgrade and does not fill.
- 30-day offline Pro user experiences zero degradation (clock-simulation test).

## Definition of Done
- Global DoD, plus: pricing copy flagged for PM review (beta-validated per PRD).

## Testing Requirements
- Entitlement matrix tests; StoreKit test-environment flows; license crypto tests; offline-grace simulation.

## Documentation Updates
- docs/specs/entitlements.md; Privacy Dashboard copy update.
