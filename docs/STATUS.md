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

## Continuation pass — 2026-09-12

- Initial implementation checkpoint: `8434d5b`.
- **31 tests pass** after the continuation refinements.
- Added MalNative with a custom field editor that captures composition at key-down, before an IME can unmark it; disables text autocorrection/replacement. Native marked-text test passes. Real 2-Set keyboard testing remains open.
- Repeated choice/Continue keys are suppressed in the study window; ordinary write-in characters and modified shortcuts are unaffected.
- Retired entries no longer occupy active learning slots. Deselected but still active entries continue to count as designed.
- Custom nested namespaces cannot take ownership of another bank's entries; reserved root `mal` is protected as well as `mal.*`.
- Native sample-bank import, save-panel backup, and open-panel restore all succeeded using `/tmp/mal-ui-smoke`. This completes the basic UI path for QA-003; edited-bank/reimport UI checks remain.
- Edited 149 verbose English prompts into concise answer lists/cues. Exact edits: `editorial-pass-001.json`. Verification status did not change.
- `content-audit.json` lists 100 entries needing early attention: 98 long prompts and 3 predicates without inflected answers (one overlaps). This is automated triage, not a linguistic correctness verdict.
- Reverse prompts omit a cue if it contains an accepted English answer. Usage notes and source citations remain separate in the study/library views.
- Packaging now verifies a complete staging app before publishing, retaining the previous app as `build/Mal.previous.<timestamp>.app`.

### Next priorities

1. Exercise the new field editor with the user's actual Korean input method.
2. Review the 100 triaged vocabulary entries, then continue source/sense/form verification of the entire corpus. Do not promote statuses based solely on the editorial gloss pass.
3. Audit tier placement and correct ambiguous source matches with explicit semantic ID migrations where needed.
- Refined package built and signature-verified successfully. Relaunched against the same isolated database; the new native field editor accepted a Korean answer and advanced correctly.

## Readability and continuous-study feedback — 2026-09-12

Implemented the user's three requested corrections:

- Multiple-choice answers use 30-point type and wrap without shrinking.
- Learning-pool size no longer produces an artificial stop when unseen words remain and no review is ready. Removed the automatic 50-answer pause. No progress reset or schema migration required.
- Wrong answers now show Incorrect, the user's answer, a large correct answer and Continue. Correction controls moved to a secondary options menu.

Validation: **33 tests passed**. Added 120-word correct-answer simulations in all four direction/mode combinations, plus a regression verifying that due failed cards take priority over new words at a full pool. Updated the filtered-pool regression to reflect continuous-study behavior. Existing grading, persistence, migration, input and content tests pass.

Release app rebuilt and signature-verified at `build/Mal.app`. Visual acceptance of the larger choices and revised incorrect-answer layout remains for user testing; automated results do not substitute for that check.

## Choice numbering correction — 2026-09-14

- User reported unreadable number labels and keyboard selections not matching displayed choices.
- Replaced row-major lazy grid with explicit top-to-bottom columns: default left 1–4, right 5–8. Number labels are now 28-point semibold with primary contrast.
- Button/keyboard actions resolve the current indexed answer, and controls receive a fresh identity when choices change.
- Validation: release build and app signature verification passed; `git diff --check` passed. No rules/storage changes; unit suite was not rerun for this UI-only patch.
- Next acceptance: verify each numeric key matches its visible answer across multiple cards, both directions, and all choice counts; check odd-sized custom banks. UI acceptance remains pending. Personal progress untouched.

## Five-choice single column — 2026-09-14

- Replaced two columns with one full-width wrapping column; default and first-updated-launch choice count is five. Subsequent manual choice-count changes persist. No progress reset.
- Added five-choice case to the parameterized choice-construction test.
- Validation: clean `swift test --scratch-path /tmp/mal-five-choice-tests` passed all 33 tests, including settings backup/restore. Initial incremental test build failed the settings equality check after the struct changed; clean recompilation resolved it. Release app build and signature verification passed.
- Next: user acceptance of long-answer wrapping and numeric keys 1–5 at the preferred window size. Actual visual acceptance remains pending.

## Compact study layout — 2026-09-14

- User screenshot showed choice 5 below the fold and a long English option truncated. Reduced excessive header/card/footer spacing and outer padding; removed the extra flexible spacer competing with the study scroll view. Kept 30-point answers and 28-point numbers.
- Replaced native bordered answer buttons with plain buttons and explicit backgrounds, unlimited text lines, and full-width wrapping labels.
- Validation: UI-only change; no rules/storage tests required. Build result recorded below. Next acceptance: reproduce the screenshot's window size and long answer, confirm five choices fit when content permits and long text wraps. Scrolling remains available for unusually long sets. Personal progress unchanged.

- Release build and signature verification passed; `git diff --check` passed. Visual acceptance remains pending.
