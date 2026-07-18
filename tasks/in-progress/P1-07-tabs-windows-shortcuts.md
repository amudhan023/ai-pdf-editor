# P1-07 — App Shell: Tabs, Multi-Window, Menus & Shortcuts

**Epic:** E3 · **Primary package:** `App/` · **Complexity:** M · **Priority:** Medium

**Owner:** claude · **Branch:** task/P1-07-tabs-windows-shortcuts · **Claimed:** ad9e6f1bac71c1cdfe4cda559d5f4a26bf642ba0

## Goal
Native document-app shell: window tabs, multiple windows, complete menu bar with keyboard shortcuts, recents, and default-PDF-app registration polish.

## Background
PRD FR-6.1 — the "feels native" bar. One DocEngine.xpc instance per document must survive tab/window moves (ARCHITECTURE.md §2.3).

## Requirements
- Tabbed windows (native tabbing), per-window toolbar, full menu tree (File/Edit/View/Annotate/Window/Help) with standard shortcut set; recents menu via security-scoped bookmarks.
- State restoration (open documents, window frames, scroll positions).
- "Set as default PDF app" onboarding affordance.

## Dependencies
- P0-07 (extends the shell); coordinate with any concurrent `App/` task — `App/` is a shared surface, serialize App-touching tasks.

## Files Likely Affected
- `App/**`.

## Acceptance Criteria
- 10 documents across tabs/windows: correct service lifecycle (verified: closing a tab tears down its service), state restoration works after relaunch.
- Menu/shortcut audit checklist passes (parity list in task appendix compiled from Preview + Acrobat).

## Definition of Done
- Global DoD.

## Testing Requirements
- XCUITest for tab lifecycle + restoration; unit tests for bookmark storage.

## Documentation Updates
- `App/CLAUDE.md` window/session lifecycle map.
