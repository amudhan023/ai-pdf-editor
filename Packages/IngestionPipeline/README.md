# IngestionPipeline

Document ingestion stage graph: normalize -> OCR -> classify -> extract -> map -> conflict-detect. Emits ExtractionCandidates only - never writes to the vault.

Part of Vaultform. See the repo root `CLAUDE.md` and `docs/ARCHITECTURE.md`.
