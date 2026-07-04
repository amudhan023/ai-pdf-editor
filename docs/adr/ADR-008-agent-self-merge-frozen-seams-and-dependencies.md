# ADR-008 — Agent Self-Merge for Frozen-Seam and New-Dependency PRs

**Status:** Accepted · **Amends:** Constitution Articles 7, 10 · **Requested by:** human maintainer, direct instruction · **Task:** none (process/governance)

## Context
Prior to this ADR, Constitution Article 7 required human approval for every new dependency, and Article 10 required human approval for every architectural change (new layers, moved responsibilities, changed process boundaries, altered frozen seams `Packages/*API/`/`Schemas/`, new entitlements) — on top of the ADR each already required. `CLAUDE.md` §21 additionally required human review for `[INTEGRATION]`, security-touching, and API/schema PRs regardless of CI status (established P0-12/P0-13).

The human maintainer explicitly asked, in the course of reviewing and merging several such PRs (P0-04 PDFEngineAPI, P0-09 VaultAPI, P0-10 PolicyKit) without finding issues, to stop waiting for that review step going forward — CI green should be sufficient. Two narrower alternatives were offered first (relax only "ordinary" PRs — already true since P0-13; or relax 10/11 but keep 7's dependency-approval given shipped-product supply-chain risk) and explicitly declined in favor of relaxing all three the same way.

## Decision
1. **Article 7 (dependencies):** the ADR requirement is unchanged (still required, same content: license, supply chain, size, build-vs-buy). The *human-approval* requirement is replaced with: self-mergeable once the ADR is recorded and CI (`ci-status`) is green.
2. **Article 10 (architecture/frozen seams):** the ADR + updated-architecture-documentation requirement is unchanged. The *human-approval* requirement is replaced with: self-mergeable once documented and CI is green — **except new entitlements**, which keep the full human-approval requirement (see Exceptions below).
3. **Article 11 (security boundaries):** no textual change. Article 11 is a substantive prohibition ("boundaries may never be weakened"), not a procedural approval gate — there was nothing in its text to relax. What *does* change is `CLAUDE.md` §21's separate "security-touching PRs need human review" rule (not a Constitution article), which is relaxed to match 7/10 in a companion PR to this one (kept separate per the Constitution's "dedicated PR touching nothing else" amendment rule).

## Exceptions (not relaxed by this ADR)
- **New entitlements / Info.plist permission changes** — always require human sign-off, no exception. This is called out with unusually emphatic, repeated language elsewhere (CLAUDE.md §7.7: "require an ADR + human sign-off"; `docs/AGENT_LOOP.md` §4: "an agent may never self-approve one") specifically because entitlements are OS-level grants with real-world device/privacy consequences beyond this repo's own development velocity. This ADR does not touch that carve-out.
- **Changes to `docs/CONSTITUTION.md`, `CLAUDE.md`, or `docs/AGENT_LOOP.md` themselves** — always require human approval, regardless of this ADR. Without this exception, an agent could use the relaxed Article 10 (architecture/process changes) to justify self-merging further changes to the very rules governing it — a self-amendment loophole that would make the human-maintainer amendment clause meaningless. This ADR is itself an instance of the exception it describes: it required (and received) explicit human sign-off.

## Consequences
- New third-party dependencies and architectural/frozen-seam changes (other than entitlements) can land without a human explicitly clicking approve, provided: the required ADR exists, CI (build + test + boundary lint + repo-wide checks) is green, and (per existing, unchanged policy) the PR doesn't touch `CLAUDE.md`/`AGENT_LOOP.md`/`CONSTITUTION.md`.
- This increases reliance on CI and the ADR-writing discipline as the actual safety net, in place of a synchronous human click. If CI coverage or ADR quality turns out to be insufficient in practice, that's a reason to revisit this ADR (write a superseding one), not to informally re-tighten the rule.
- The human maintainer's review capacity is now spent on: entitlements, governance-doc changes, and whatever they choose to spot-check after the fact (task Journals remain the audit trail per Article 14).
