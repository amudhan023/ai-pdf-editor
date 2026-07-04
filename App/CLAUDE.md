# App

**Purpose:** Xcode app target — DI composition root, windows, tabs, menus, onboarding.
Created as a real target by task P0-07. Shared surface: App-touching tasks are serialized
(one in-progress task may own App/ at a time — see tasks/README.md).

**Verify:** app target builds via Xcode; packages via `Scripts/verify.sh`.

**Invariants:** composition root only — no business logic here; wire protocols to
implementations and nothing else.
