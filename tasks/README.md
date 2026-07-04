# Task Backlog — Workflow & Conventions

Tasks are the unit of work for one Claude Code agent (or one engineer). Each task file is a complete, self-sufficient prompt: an agent should need only the task file, the referenced docs sections, and the target package's `CLAUDE.md`.

## Workflow

1. Pick the highest-priority unblocked task from `backlog/<current-phase>/` (dependencies listed in each file must be in `done/`).
2. Move the file to `in-progress/`, add a line at the top: `**Owner:** <agent/human> · **Branch:** task/<ID>-<slug>`.
3. Branch `task/<ID>-<slug>`; do the work; run `Scripts/verify.sh <Package>`.
4. PR body links the task file. On merge, move the file to `done/`.

## Parallelism & conflict rules

- **One task = one package** (the `Primary package` field). Tasks marked `[INTEGRATION]` may touch multiple packages and must not run concurrently with other tasks touching those packages.
- Never edit `Packages/*API/` or `Schemas/` inside a normal task — if you need an interface change, stop and open an ADR + an `[INTEGRATION]` task.
- Tasks within the same folder with disjoint primary packages are safe to run in parallel.

## Global Definition of Done (applies to every task; task files list only *additions*)

- [ ] `Scripts/verify.sh <PrimaryPackage>` green (build + tests + boundary lint)
- [ ] New behavior covered by colocated tests; fixtures added via manifest where applicable
- [ ] Package `CLAUDE.md` updated if invariants/usage changed
- [ ] No vault values or document content in logs; no new network calls (red lines in root `CLAUDE.md`)
- [ ] Conventional commit(s) scoped by package; PR links this task file; task file moved to `done/`

## Complexity scale

**S** ≈ ≤1 agent-day · **M** ≈ 1–3 days · **L** ≈ 3–5 days (anything larger must be split)

## Priority scale

**Critical** = on the roadmap critical path (E1→E2→E7→E12→E13→E16) · **High** = milestone exit criteria · **Medium** = MVP scope, has slack
