# Vaultform

A professional, native macOS PDF editor with a privacy-first AI Autofill Assistant: all personal data lives in an encrypted local vault; PDF forms — including scanned and flat ones — are filled from it with full user review and zero network dependency.

## Quickstart

```bash
Scripts/bootstrap.sh          # prerequisites check + build + verify all packages
Scripts/verify.sh <Package>   # build + tests + boundary lint for one package
```

Requires Xcode 16+ (Swift 6). Install `git-lfs` before working with binary fixtures.

## Read first

| Doc | What it is |
|---|---|
| [`docs/CONSTITUTION.md`](docs/CONSTITUTION.md) | Fifteen immutable rules — outrank everything |
| [`CLAUDE.md`](CLAUDE.md) | The operating manual for all agents and humans |
| [`docs/PRD.md`](docs/PRD.md) · [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | What we're building; how it's designed |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) · [`tasks/`](tasks/) | Dependency-sequenced waves; the executable backlog |
| [`docs/AGENT_LOOP.md`](docs/AGENT_LOOP.md) | The autonomous development loop |
| [`okf/index.md`](okf/index.md) | AI-agent knowledge bundle — progressive-disclosure map of the architecture; start here for fast orientation before reading source |

## Layout

`Packages/` — one SPM package per architecture module (agent workspaces) · `Services/` — the three sandboxed XPC services · `App/` — composition root · `Schemas/` — codegen sources (frozen seam) · `Fixtures/` — test corpora (synthetic data only) · `tasks/` — backlog / in-progress / done · `okf/` — AI-agent knowledge bundle (progressive-disclosure architecture map).
