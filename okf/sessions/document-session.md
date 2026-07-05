---
type: session
title: DocumentSession
description: Document lifecycle state machine — open/edit/atomic-save/backups, undo stack, viewer/annotation/form-fill UI. Currently a placeholder stub.
tags: [session, application-layer, document-lifecycle, undo, stub]
implementation_status: scaffolded
---

# DocumentSession

**Purpose (per its `CLAUDE.md`, not yet realized in code):** document lifecycle — open → edit → atomic save → versioned backup, undo/redo stack, dirty-state tracking, recovery journal, and (per its own `CLAUDE.md` phrasing) the viewer + annotation + form-fill UI itself. It must never perform PDF byte manipulation directly — that's delegated to the engine via `PDFEngineAPI` ([../packages/pdf-engine-api.md](../packages/pdf-engine-api.md)).

## Current state

`Packages/DocumentSession/Sources/DocumentSession/DocumentSession.swift` is a 4-line placeholder. No state machine, undo stack, or save-path implementation exists yet.

## A layering note worth flagging

Its `CLAUDE.md` purpose line explicitly includes "viewer + annotation + form-fill UI" as part of this Application-layer package's scope, while `docs/ARCHITECTURE.md`'s layer diagram puts Document Windows/viewer UI in the *Presentation* layer, separate from the `DocumentSession` coordinator. This is a real, documented tension worth checking directly against the package's `CLAUDE.md` when this package is actually built, rather than assuming the idealized diagram is how the split will land — see [../architecture/layered-architecture.md](../architecture/layered-architecture.md).

## Design intent (`docs/ARCHITECTURE.md` §3.2, product truth 5)

All document mutation flows through the atomic save path: write-to-temp → validate (re-parse check) → atomic replace → versioned backup. This is the structural guarantee behind "never corrupt a user's document. Ever." — see [../architecture/five-product-truths.md](../architecture/five-product-truths.md) and [../architecture/storage-layout.md](../architecture/storage-layout.md).

## Allowed imports

Foundation, `PDFEngineAPI`, `Platform`.
