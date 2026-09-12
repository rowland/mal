# Mal implementation status

Last updated: 2026-09-12. This is the handoff entry point. Read REQUIREMENTS.md and DECISIONS.md before changing behavior.

## Delivered development build

- SwiftUI app with all four study combinations, eight-choice default and 4/6/8/10 settings, full-bank distractors, part-of-speech filters, write-in field, immediate correct advancement, paused errors, override/alias and undo.
- Searchable bank browser, system pronunciation, settings and history.
- Pure MalCore rules module: grading, distractors, queue, scheduling and independent direction/mode state.
- SQLite content, aliases, presentations, attempts, schedules and settings; atomic grades/overrides, versioned bank updates, retirement/reactivation, standalone backups and pre-restore recovery.
- YAML v1, sample import, command-line validator, five 500-entry banks and frozen content source manifest.
- Reproducible `scripts/build-app.sh` produces `build/Mal.app` (local ad-hoc signature).

## Milestones

| Milestone | Status | Remaining acceptance |
|---|---|---|
| M1 Foundation | Implemented | User review of workflow and project discipline |
| M2 Vertical slice | Implemented and smoke-tested | Actual Korean IME composition, broader keyboard/voice/accessibility testing |
| M3 Learning engine | Implemented and unit-tested | Longer real-study feedback and scheduling preference refinement |
| M4 Content lifecycle | Implemented and integration-tested | Full UI import/restore acceptance pass |
| M5 Full v1 | Incomplete | Independent linguistic verification and tier audit; final UI acceptance |

## Vocabulary gate

2,500 unique entries: 49 editorially checked, 2,451 draft source matches, zero independently verified. All five banks are structurally valid. The `--release` validator fails intentionally. Do not describe this as a completed verified v1.

## Test evidence

- Debug and optimized builds succeed on Xcode 26.6 / Swift 6.3.3 / macOS 26.5.2 ARM64.
- Last recorded full suite before final color regression addition: 24 tests passed, including migration/future-version rejection, standalone backup/restore, corrupt payload rejection, all four tracks, and 2,500-entry structural validation. Final run appended below.
- Native smoke test used `MAL_DATA_DIRECTORY=/tmp/mal-ui-smoke`, keeping normal learning progress untouched. Verified app launch, eight choices, numeric correct advancement, wrong-answer pause, ⌘Z undo, independent write-in mode, pasted Korean + Return submission, ⌘L library, and Korean search.
- Pasted Hangul is **not** an IME composition test. UI-06 remains open.
- Release gate tested: exits 1 for unverified entries as required.

## Backlog / defects

| ID | Priority | State | Work |
|---|---|---|---|
| DEF-001 | P1 | Fixed, regression-tested | Export SQLite backups in standalone journal mode so read-only restore works. |
| DEF-002 | P2 | Fixed | Avoid immediate repetition of an ungraded card on mode/filter changes. |
| CONTENT-001 | P1 | Open | Independently verify senses, conjugated forms, aliases and labels for all 2,500 entries. |
| CONTENT-002 | P1 | Open | Audit auto-matched polysemy and NIKL source alignment; source match is not proof of the intended sense. |
| CONTENT-003 | P2 | Open | Reassess five-tier placement, especially Advanced/Extra; current placement is preliminary A/B/C plus frequency. |
| QA-001 | P1 | Open | Real 2-Set Korean IME: composition commit, recomposition and backspace; do not mark based on paste tests. |
| QA-002 | P2 | Open | Held-key/rapid input behavior, minimum-size layout, dark mode, VoiceOver, voice availability. |
| QA-003 | P2 | Open | Native file-panel import/update and backup/restore acceptance; storage path already integration-tested. |
| ENG-001 | P2 | Open | Add version-2 migration fixtures when the first schema change is designed. Current migration tests cover an unversioned fixture and rejection of future schemas. |

## Next iteration

1. Run the app with normal personal data only when ready to study; the smoke-test instance is disposable.
2. Have the user exercise UI-01 through UI-15 in TESTING.md and report defects by ID or reproduction steps.
3. Review vocabulary in small, auditable batches. Preserve IDs and increase contentVersion. Use content-manifest.json to recover source evidence; do not rerun initial assembly over published IDs.
4. Resolve P1 content/IME items before marking v1 ready. Maintain independent user acceptance and automated results.

## Working conventions

Keep commits focused. Update this status file after each iteration with exact checks run, open defects and the next concrete action. Never erase user progress for convenience; test against temporary stores. No remote repository or external issue service has been configured.

## Final checks for this iteration

- `swift test`: **25 tests passed**, 2026-09-12 (including checked red-synonym regression).
- `scripts/build-app.sh`: optimized build and app packaging succeeded after fixing repeat-copy permissions (DEF-003).
- `codesign --verify --deep --strict build/Mal.app`: passed.
- Sample bank validator: passed. All five bundled banks: 500 entries each, structural validation passed. Linguistic release gate: failed as expected.
- DEF-003: Fixed repeat app packaging when SwiftPM resources are copied read-only; subsequent packaging and signature verification passed.
