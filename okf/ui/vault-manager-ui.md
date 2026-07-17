---
type: ui-component
title: VaultManagerUI
description: The vault window — profile management, field editing, sensitivity masking, unlock UX. Talks to the vault only through VaultAPI. Currently a placeholder stub.
tags: [ui-component, presentation-layer, vault, stub]
implementation_status: scaffolded
---

# VaultManagerUI

**Purpose (per its `CLAUDE.md`, not yet realized in code):** the vault management window — profile CRUD, field editing, sensitivity-tier masking in the UI, and unlock UX (biometric/password prompts). Must talk to the vault only through `VaultAPI` client protocols ([../packages/vault-api.md](../packages/vault-api.md)) — never bypass to a store implementation directly.

## Current state

`Packages/VaultManagerUI/Sources/VaultManagerUI/VaultManagerUI.swift` is a 4-line placeholder. No views or view models exist yet — **P1-11 is in progress** (check `tasks/in-progress/` before touching this package).

## Design intent

Renders `Person`/`ProfileField`/`HistoryEntry`/`RelationshipEdge` data ([../packages/vault-api.md](../packages/vault-api.md)) for CRUD; masks `.sensitive`-tier fields by default, requiring a fresh re-auth to reveal (surfacing `PolicyKit`'s `requireReauth` decision as a UX affordance, not an error — [../architecture/security-model.md](../architecture/security-model.md)); any vault-value copy-to-pasteboard action is meant to use a transient pasteboard type with expiry (root CLAUDE.md §7.4).

## Allowed imports

Foundation, `VaultAPI`, `PolicyKit`.
