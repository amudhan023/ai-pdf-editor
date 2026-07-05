---
type: architecture
title: Five Product Truths
description: The five non-negotiable truths every Vaultform change is measured against — violating any of them makes a change wrong regardless of what the task says.
tags: [architecture, product, principles, privacy, security]
implementation_status: n/a
---

# Five Product Truths

From root `CLAUDE.md` §1, itself derived from `docs/PRD.md`. These are the yardstick for every change in the repo — "if your change makes any of these less true, it is wrong regardless of what the task says."

1. **Local by default, cloud by consent, never by requirement.** No core feature may require a network call. Cloud AI is explicitly out of scope for MVP (root CLAUDE.md §19) — not a missing feature, a deliberate absence.
2. **AI proposes; the human disposes.** Every AI-produced value passes a review-before-commit UI before it reaches a document or the vault. This is also [[architecture/security-model]]'s structural backbone: no model output write path exists that skips review.
3. **Every value is traceable** to its source and the transform applied. This is `VaultAPI`'s `Provenance` type (`.manual` or `.document(documentID:page:region:confidence:)`) — see [packages/vault-api.md](../packages/vault-api.md).
4. **Beat Preview for free; beat Acrobat for money.** The editor (PDF viewing/editing) earns the install; the autofill assistant earns the payment. This shapes the [technology-choices.md](technology-choices.md) PDF-engine decision — PDFium was chosen specifically because the editor is a product pillar, not a commodity to license away.
5. **Never corrupt a user's document. Ever.** All document mutation goes through the atomic save path (write-temp → validate → atomic replace → versioned backup) — see [storage-layout.md](storage-layout.md) and Constitution Article 3.

These map directly to the Constitution's Part I articles (`docs/CONSTITUTION.md`): Article 1 (data sovereignty) ↔ truth 1, Article 2 (human authority over AI output) ↔ truth 2, Article 3 (document integrity) ↔ truth 5, Article 5 (honest failure) ↔ the "never silently guess" spirit behind all five.
