# Repository Structure — Optimized for Long-Term AI-Assisted Development

| | |
|---|---|
| **Version** | 1.0 · July 3, 2026 |
| **Companion docs** | [ARCHITECTURE.md](ARCHITECTURE.md) · [ROADMAP.md](ROADMAP.md) |

## 1. Design Principles

AI agents (and new humans) are most effective when the repo gives them: **small, bounded workspaces; local context; executable verification; and disjoint merge surfaces.** Every choice below serves one of those.

1. **One SPM package per architecture module.** A task assigns an agent *one package*; the package's `Sources/`, `Tests/`, and `CLAUDE.md` are its whole world. Cross-package coupling only through `*API` protocol packages → merge conflicts are structurally rare, not behaviorally avoided.
2. **Context travels with code.** Root `CLAUDE.md` holds global invariants; every package has its own `CLAUDE.md` (purpose, invariants, forbidden dependencies, how to test *this* package in isolation). Agents never need the whole repo in context.
3. **Interface-first layout.** Protocol/API packages (`PDFEngineAPI`, `InferenceAPI`, `VaultAPI`) are separate from implementations, land first (roadmap freeze points), and change via ADR — so parallel tasks build against stable seams.
4. **Executable verification per package.** `Scripts/verify.sh <package>` = build + tests + boundary lint for that package only. An agent can prove its work without running the full app; CI runs the same script, so "works for the agent" = "works in CI".
5. **The backlog lives in the repo** (`tasks/`). Task files are the prompt; moving files between `backlog/ → in-progress/ → done/` is the workflow state. Reviewable, diffable, agent-legible.
6. **Decisions are files** (`docs/adr/`). Agents check ADRs before "improving" architecture; humans record every seam-level change.
7. **Determinism where agents are weak:** XPC DTOs and PolicyTicket types are generated from a single schema source (`Schemas/`) — agents edit the schema, codegen keeps both sides of every process boundary in lockstep.
8. **Fixtures are first-class.** The PDF corpus and document fixtures live in-repo (LFS) with manifest files describing expected outcomes — tests read manifests, so adding a regression case is a data change, not a code change.

## 2. Directory Layout

```
ai-pdf-editor/
├── CLAUDE.md                    # global: build cmds, invariants, layer rules, style
├── README.md
├── docs/
│   ├── PRD.md
│   ├── ARCHITECTURE.md
│   ├── ROADMAP.md
│   ├── REPO_STRUCTURE.md
│   ├── adr/                     # ADR-001-pdf-engine.md, ADR-002-xpc-topology.md …
│   └── specs/                   # feature specs written per-epic before build
├── tasks/
│   ├── README.md                # workflow, global Definition of Done, conventions
│   ├── _TEMPLATE.md
│   ├── backlog/
│   │   ├── phase-0-foundation/
│   │   ├── phase-1-core-pillars/
│   │   ├── phase-2-intelligence/
│   │   └── phase-3-beta-ga/
│   ├── in-progress/             # task file moves here w/ branch + owner noted
│   └── done/                    # moved on merge; becomes historical record
├── App/                         # Xcode app target: composition root, windows, menus
│   └── CLAUDE.md
├── Packages/                    # ← the agent workspaces (SPM, one per module)
│   ├── PDFEngineAPI/            #   protocols only — change via ADR
│   ├── VaultAPI/                #   VaultModel types + client protocols + PolicyTicket
│   ├── InferenceAPI/            #   typed inference request/response protocols
│   ├── DocumentSession/
│   ├── AutofillSession/
│   ├── IngestionSession/
│   ├── VaultManagerUI/
│   ├── PrivacyDashboard/
│   ├── AutofillEngine/
│   ├── IngestionPipeline/
│   ├── PolicyKit/
│   ├── FormKnowledge/
│   ├── AuditLog/
│   ├── DocEngineHost/           # XPC client + PDFium adapter (impl of PDFEngineAPI)
│   ├── InferenceHost/
│   ├── VaultStore/
│   └── Platform/                # Keychain, LAContext, file coordination wrappers
│       └── (each package:) Sources/ · Tests/ · CLAUDE.md · README.md
├── Services/                    # the three .xpc bundle targets (thin mains over Packages)
│   ├── DocEngineService/
│   ├── InferenceService/
│   └── VaultService/
├── Schemas/                     # single source of truth → codegen
│   ├── xpc-dtos.yml
│   └── vault-schema.yml
├── ThirdParty/
│   └── pdfium/                  # pinned build recipe + prebuilt binaries (LFS)
├── Fixtures/                    # git-lfs
│   ├── pdf-corpus/              # rendering/round-trip suite + manifest.json
│   ├── forms/                   # top-100 target forms + expected-fill manifests
│   └── documents/               # synthetic IDs/resumes for ingestion tests (NO real PII)
├── Scripts/
│   ├── bootstrap.sh             # clone → building in one command
│   ├── verify.sh                # verify.sh <Package> = build+test+lint that package
│   ├── codegen.sh               # regenerate DTOs from Schemas/
│   ├── bench.sh                 # run benchmark suites (accuracy, perf)
│   ├── corpus-roundtrip.sh      # 10K-document no-corruption suite
│   └── network-audit.sh         # packet-capture walkthrough gate
├── .github/workflows/           # ci.yml (per-package matrix), bench.yml, release.yml
└── .swiftlint.yml + boundary rules (import allowlist per package)
```

## 3. Conventions That Make AI Development Safe at Scale

| Convention | Rule | Why for agents |
|---|---|---|
| **Package boundaries** | A package may import only: its declared `*API` packages + Foundation-tier deps. Enforced by lint in `verify.sh` and CI. | Agents physically cannot create hidden coupling; reviews stay local. |
| **File size** | Soft cap ~400 lines/file; split by responsibility. | Smaller edit targets → cleaner diffs, fewer conflicts, better context use. |
| **One task = one package (default)** | Tasks touching >1 package are integration tasks, explicitly marked, serialized per phase. | Two agents on two tasks never write the same file. |
| **API changes are ADR events** | Editing `Packages/*API/` or `Schemas/` requires an ADR entry + humans in review. | Protects the freeze points that parallelism depends on. |
| **Tests colocated + manifest-driven fixtures** | New regression = add fixture + manifest row. | Agents extend coverage without inventing test scaffolding. |
| **`CLAUDE.md` hygiene** | Package CLAUDE.md ≤ 60 lines: purpose, invariants (e.g. "no String bridging of SecureBytes"), forbidden imports, `verify.sh` invocation, gotchas. Updated in the same PR as behavior changes. | The doc an agent reads first is always current and small. |
| **Branch/PR naming** | `task/P2-05-fill-planner`; PR body links the task file; merging moves task to `done/`. | Traceability from roadmap → task → diff, automatable. |
| **Commit style** | Conventional commits scoped by package: `feat(AutofillEngine): …` | Changelogs and blame stay navigable across hundreds of agent PRs. |
| **No real PII in fixtures — ever** | Synthetic generators only; CI secret-scan + PII-pattern scan on `Fixtures/`. | Agents test ingestion/vault against realistic but safe data. |

## 4. Root `CLAUDE.md` (contents outline)

1. What this product is (3 lines) + pointers: PRD, ARCHITECTURE, current phase in ROADMAP.
2. Golden commands: `Scripts/bootstrap.sh`, `Scripts/verify.sh <Pkg>`, `Scripts/bench.sh`.
3. The five architectural invariants (from ARCHITECTURE §1) — verbatim, non-negotiable.
4. Layer/import rules table; "if you need a new cross-package dependency, stop and write an ADR."
5. Task workflow: pick from `tasks/backlog/<current-phase>/`, follow template, move file, global DoD.
6. Security red lines for generated code (no network calls, no vault value logging, SecureBytes rules).

## 5. Why This Layout Ages Well

- **Context windows stay small forever:** work is package-scoped, docs are package-scoped, verification is package-scoped — repo size growth doesn't grow the per-task context.
- **Merge conflicts are designed out, not managed:** disjoint workspaces + frozen seams + schema codegen mean parallel agent PRs rarely touch the same files; the exceptions (API packages, App composition root) are explicitly gated.
- **The repo is self-describing:** an agent dropped in cold can go from `CLAUDE.md` → task file → package `CLAUDE.md` → `verify.sh` without a human in the loop, and a human reviewer can audit the same chain in reverse.
