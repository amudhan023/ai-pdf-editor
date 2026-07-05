---
type: index
title: Packages Index
description: The frozen *API contract packages plus the substantively-implemented infra packages (PolicyKit, Platform).
tags: [packages, api-contracts, overview]
---

# Packages

The three `*API` packages are **frozen seams** (root CLAUDE.md §3.6): protocols/DTOs only, changing them requires a superseding ADR + `[INTEGRATION]` PR. `PolicyKit` and `Platform` are ordinary Domain/Infrastructure packages that happen to already have real implementations. The remaining infra/domain packages (`AuditLog`, `FormKnowledge`) are still stubs.

| Package | Role | Status |
|---|---|---|
| [pdf-engine-api.md](pdf-engine-api.md) | Engine-neutral PDF protocols + value types | Implemented (protocols/types/fake/conformance suite; no real engine) |
| [vault-api.md](vault-api.md) | Vault domain model + client protocol | Implemented (protocols/types/fake/conformance suite; no real store) |
| [inference-api.md](inference-api.md) | Typed inference request/response contracts | Scaffolded (stub) |
| [policy-kit.md](policy-kit.md) | Deterministic policy rules + ticket minting/verification | Implemented |
| [platform.md](platform.md) | OS service wrappers: XPC transport, Keychain, LAContext, file coordination | Partial (XPC transport implemented; rest not built) |
| [audit-log.md](audit-log.md) | Append-only hash-chained audit log | Scaffolded (stub) |
| [form-knowledge.md](form-knowledge.md) | Form fingerprinting + mapping memory + template packs | Scaffolded (stub) |

For the engine/store packages that *implement* these API protocols (`DocEngineHost`, `InferenceHost`, `VaultStore`), see [../engines/index.md](../engines/index.md).
