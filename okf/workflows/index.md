---
type: index
title: Workflows Index
description: The two cross-component sequence flows that define how data moves through the system — ingestion and autofill.
tags: [workflows, sequence, overview]
---

# Workflows

Cross-component sequence flows from `docs/ARCHITECTURE.md` §5, spanning Sessions → Engines → Services. **Both flows remain design intent end-to-end** — the coordinating sessions (`IngestionSession`/`AutofillSession`) and `IngestionPipeline` are still stub packages, though several building blocks now exist: the alias-matcher rung (`AutofillEngine`), OCR and embed endpoints (`InferenceHost`), and ticketed vault reads/writes with `compareRead` (`VaultStore`). See [../sessions/index.md](../sessions/index.md), [../engines/index.md](../engines/index.md).

| Flow | Direction | Only-write-path invariant |
|---|---|---|
| [ingestion-flow.md](ingestion-flow.md) | Document → Vault | Only `IngestionSession`, on explicit user confirmation, writes to the vault |
| [autofill-flow.md](autofill-flow.md) | Vault → Form | Only `AutofillSession`, committing accepted proposals, writes to the document |
