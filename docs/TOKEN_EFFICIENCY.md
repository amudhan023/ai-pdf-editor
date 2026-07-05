# Token & Cost Optimization — Operating Strategy for Claude Code Agents

| | |
|---|---|
| **Version** | 1.0 |
| **Scope** | Every agent iteration, for the life of the project (thousands of iterations) |
| **Companion docs** | [AGENT_LOOP.md](AGENT_LOOP.md) (the loop this optimizes) · [CLAUDE.md](../CLAUDE.md) |

**The cost model:** total cost ≈ Σ over iterations of (context read + output written + retries). At thousands of iterations, a 20% per-iteration saving dwarfs any one-time optimization. The three levers, in order of impact:
1. **Don't read what you don't need** (biggest lever — reading is the dominant cost).
2. **Don't re-derive what's already recorded** (second biggest — repeated analysis is pure waste).
3. **Don't iterate on preventable failures** (wrong guesses, skipped checks, ambiguity discovered late).

Quality gates are never traded for tokens: a cheap iteration that fails review costs more than an expensive one that merges. Efficiency means *precision*, not corner-cutting.

---

## 1. Incremental Context Loading

Load context as a ladder; stop climbing the moment you can act.

| Rung | Load | Typical sufficiency |
|---|---|---|
| 0 | `okf/index.md` → the relevant `okf/<dir>/*.md` concept file(s) | Fast orientation on architecture/package/service shape before touching source at all — cheaper than Rung 1-3 reads for "what is this and how does it fit" questions |
| 1 | Root `CLAUDE.md` + task file | Enough to plan for S-complexity tasks |
| 2 | + primary package `CLAUDE.md` + its test file *names* | Most M tasks |
| 3 | + cited doc *sections* + "Files Likely Affected" | Almost everything |
| 4 | + consumer search results (grep, then read hits only) | `[INTEGRATION]` tasks |
| 5 | + an ADR or spec | Only when a rule/contract is in question |

**Hard budgets (exceeding one = signal to stop and reassess, not permission to continue):**
- ≤ 15 source files read per task; ≤ 3 doc sections; ≤ 1 full document ever (the task file).
- If Rung 3 leaves you unable to plan, the problem is the task or the docs, not your reading volume — escalate a clarification (§11) instead of reading wider.
- **`okf/` is a map, not a source of truth.** Its concept files carry an `implementation_status` field precisely so a Rung-0 read doesn't get mistaken for a verified one — if what you're about to do depends on a specific type, protocol, or behavior being real, confirm it against the actual package (`*API` first, per §3) before acting, not against the summary alone.

## 2. Reading Only Relevant Documentation

- **Citation-driven reads only.** Task files cite sections ("ARCHITECTURE.md §5.2"); read exactly those. Never read PRD.md for an implementation task — product intent is already compiled into the task's requirements.
- Docs are written with stable §-anchors precisely so partial reads work; read by section offset, not whole-file.
- If you read a doc section and it didn't change what you did, note it in the Journal ("§X cited but unneeded") — loop retros use this to fix over-citation in task templates.
- Never read another doc "to be safe." Safety comes from gates, not from prophylactic reading.

## 3. Reading Only Relevant Files

- **Search before read, always:** grep for the symbol/behavior, then read only hits — and read *ranges around hits*, not whole files.
- **API-first rule:** to understand another package, read its `*API` package (small, stable, documented) — never its implementation sources. If the API package doesn't answer the question, that's a doc defect to file, still not a license to read implementations.
- Never read: generated code (`Schemas/` output), `Fixtures/` payloads (read manifests instead), `done/` task files (read `phase-<n>-lessons.md` instead), lockfiles, third-party sources.
- Re-reading a file you just edited to "verify" is waste — the edit tool fails loudly; trust it.

## 4. Targeted Testing

- Local runs are scoped: single test → test class → `verify.sh <PrimaryPackage>`. Full matrices, corpus suites, and cross-package runs belong to CI — never run them locally on a hunch.
- Reproduce a failure with the *narrowest* command before diagnosing; don't re-run broad suites to observe one failing case.
- Bench suites: run only the suite owning your path, only when your diff touches a benched path (AGENT_LOOP §5). Never run benches "to see."
- When a test fails, read the failure output and the test source — not the whole subsystem. Widen only when the narrow read disproves your hypothesis.

## 5. Incremental Refactoring

- Refactor only within files you're already touching for the task ("boy-scout within the diff"); separate commits, same PR.
- **Never** launch repo-wide sweeps (rename campaigns, style migrations, "modernization"). If a sweep seems warranted, file one task proposing it with the trigger evidence — sweeps are scheduled work, not impulses.
- Prefer 10 one-file refactors across 10 tasks over 1 ten-file refactor: same improvement, near-zero merge risk, no giant-diff review cost.
- A refactor that requires reading files outside your task's scope to do safely is by definition not incremental — file it instead.

## 6. Context Preservation (external memory over re-reading)

- **The Journal is your working memory.** Findings, dead ends, file-purpose notes go there the moment you learn them; when a session ends or compacts, the Journal — not your context — is the source of truth for resuming.
- Resume protocol after interruption: read the Journal, the diff (`git diff main...HEAD`), and nothing else. If that's insufficient to resume, the Journal was under-kept — that's the defect to correct.
- One-fact-one-home (CLAUDE.md §21) is a token rule too: a fact recorded in the right doc is read once per agent that needs it; a fact re-derived is paid for on every iteration forever.
- Cross-iteration knowledge goes into package `CLAUDE.md` "gotchas" (≤60-line cap forces curation) — the highest-leverage 60 lines in the repo, because *every* future agent in that package reads them.

## 7. Avoiding Repeated Analysis

- **Conclusions are artifacts.** Any analysis that took real effort (why an API behaves oddly, why a design was chosen, what a spike found) must land in an ADR, spec, or package CLAUDE.md before the task closes — otherwise the next agent pays for it again. Rule of thumb: analysis worth 30+ minutes of agent time is worth 5 lines of documentation.
- Before analyzing, check whether the conclusion already exists: package CLAUDE.md gotchas → relevant spec → ADR index (`docs/adr/` filenames are the index — read titles, not files).
- Settled decisions are not re-analyzed (§12). Reading five files to convince yourself an ADR is right is waste; the ADR *is* the conviction.
- The `loop-metrics.md` line per task (files read, strikes) exists to catch systematic re-analysis: if three agents each read the same 8 files in one package, the retro converts that into 6 lines of package CLAUDE.md.

## 8. Handling Large Files

- Read large files by search-hit ranges or explicit offsets — never top-to-bottom. If you must understand a large file's shape, read its symbol outline (grep for `func |class |struct |extension `) before any body.
- The 400-line soft cap (CLAUDE.md §4) is a token rule: when your task touches a file over the cap, split it as part of the task *if the split stays in-package and is mechanical*; otherwise file a split task.
- Never paste large file contents into Journals, PR bodies, or docs — reference `path:line` (clickable, free).
- Large fixtures/corpora are opaque: interact via manifests and scripts only.

## 9. Efficient Documentation Updates

- Edit deltas, never rewrites: change the sentences that are now false; don't regenerate documents (regeneration costs full-document output tokens *and* review attention, and it destroys blame history).
- Docs update in the same PR as code (no second-pass "doc tasks" that require re-loading the same context later — the context is hot *now*).
- Adding to a doc: append/insert at the correct anchor; don't restructure sections unless the task is a doc task.
- When a doc edit would cascade (fact moved homes, term renamed), stop — cascading doc changes are `[INTEGRATION]`-shaped; file rather than chase.

## 10. Efficient Task Selection

- Select on **metadata only**: the header line (Epic/Package/Complexity/Priority) + Dependencies section. Never read multiple task bodies to "compare" — priority and dependency order already encode the comparison; read one body: the task you claim.
- Prefer tasks in packages you touched recently *within the same session* (context still hot) when priorities tie.
- If selection requires reasoning about more than the current phase folder, the backlog needs grooming — file the grooming observation, pick the obvious task, move on.

## 11. When to Stop and Ask for Clarification

Asking costs ~50 tokens; guessing wrong costs a full iteration plus review plus rework. Ask (via `tasks/escalations/`, per AGENT_LOOP §9) **before implementing** when:
- Two readings of an acceptance criterion lead to materially different diffs.
- The task conflicts with a rule, an ADR, or observed code reality.
- The work requires a frozen seam, new dependency, entitlement, or money.
- Rung-3 context is insufficient to plan (§1) — the task is under-specified.
- Your planned diff exceeds ~2× the task's Complexity expectation (S turning into L means the task or your approach is wrong).

Do **not** ask when the answer is derivable from CLAUDE.md, the cited sections, or a convention with an obvious default — state the assumption in the Journal/PR and proceed. The escalation should contain the question, your recommended answer, and what you'll do if unanswered (park vs. proceed-on-assumption); one round-trip, never a dialogue.

## 12. Avoiding Unnecessary Architectural Redesign

The single most expensive failure mode in long-running agent projects is **re-litigating settled design**. Rules:

1. **The architecture is settled by default.** ADRs and ARCHITECTURE.md are conclusions, not proposals. An agent's dislike of a pattern is not evidence; benchmarks, gate failures, and defects are.
2. Redesign may only be *proposed* (draft ADR via escalation), never *performed* inline — and only when triggered by concrete evidence: a budget that can't be met, a gate that keeps failing structurally, or the drift review finding real divergence.
3. **Improvement ≠ redesign.** Better naming, extracted helpers, added tests inside your package: welcome. New layers, moved responsibilities, replaced mechanisms, "simplified" seams: ADR path, no exceptions — even when the change looks strictly better.
4. Rebuild-vs-repair bias: prefer the smallest diff that satisfies the acceptance criteria. If a rewrite genuinely is smaller than a repair, say so in the PR with the size comparison — that claim is checkable.
5. Never modernize working code to a newer idiom as a side effect. Idiom migrations are sweeps (§5).
6. The escape valve is real and cheap: a two-paragraph draft ADR costs almost nothing and gets a human decision. Use it instead of either silent redesign *or* silent resentment encoded as workarounds.

---

## Appendix — Per-Iteration Token Checklist

```
Before reading:   is it cited, in-package, or a grep hit? (else don't)
Before analyzing: is the conclusion already written somewhere small?
Before running:   is this the narrowest command that answers the question?
Before writing:   delta, not rewrite; reference, not paste
Before guessing:  would a 50-token question be cheaper than being wrong?
Before redesign:  stop. ADR or nothing.
After learning:   is it recorded where the next agent will find it?
```
