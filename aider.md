# AIDER.md — Vaultform Local Operating Manual

**This is the single source of truth for the local Aider agent working in this repository.**
Precedence of instruction: (0) `docs/CONSTITUTION.md` — immutable → (1) this file → (2) your task file in `tasks/`. 

---

## 1. Product Goals
Vaultform is a native macOS PDF editor with a privacy-first AI Autofill Assistant. All personal data lives in an encrypted local vault; PDF forms are filled from it with zero network dependency.

The five product truths every change is measured against:
1. Local by default, cloud by consent, never by requirement.
2. AI proposes; the human disposes.
3. Every value is traceable.
4. Beat Preview for free; beat Acrobat for money.
5. Never corrupt a user's document. Ever.

## 2. Architecture & Safety Rules (Non-Negotiable)
1. **No network calls** anywhere except the enumerated, consented app-level paths. Local model execution only.
2. **Layering:** Presentation → Application → Domain → Infrastructure. Lower layers never import upper ones.
3. **No model output writes directly** to a document or the vault. All writes flow through an explicit user confirmation session state.
4. **Absolute rule: no document content, vault values, filenames under the user's home, or personal data at any log level or LLM payload context.**

## 3. Coding Standards
- **Language:** Swift 6, strict concurrency. Obj-C++ only inside the PDFium shim.
- **Concurrency:** `async/await` + actors. No `DispatchQueue` in new code without justification.
- **Types:** Value types by default; `Sendable`/`Codable` for anything crossing XPC. No force-unwraps (`!`) outside tests.

## 4. Definition of Done
- [ ] `Scripts/verify.sh <PackageName>` green (build + tests + boundary lint).
- [ ] New behavior covered by tests.
- [ ] Conventional commits scoped by package; PR links the task file; task file moved to `done/` on merge.