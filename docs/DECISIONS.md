# Decision log

## 2026-09-12 — accepted product decisions

- D-001: Working name is Mal (말).
- D-002: Personal offline macOS app; five banks of 500 sense entries each.
- D-003: YAML authoring, strict grading with override, system pronunciation in v1.
- D-004: Eight multiple-choice options, configurable to 4/6/8/10. Distractors use full selected banks.
- D-005: Manual answer-mode switching; independent scheduling and mastery for every direction × mode.
- D-006: Parts of speech are filters, not weights. Default all.
- D-007: Continuous rotation, not daily budgets. Correct answers auto-advance.
- D-008: Repository Markdown project tracking; no external issue service.

## 2026-09-12 — implementation decisions

- D-009: Swift Package Manager provides an Xcode-openable project and CLI build/test. A packaging script produces a native ad-hoc-signed app. No generated Xcode project dependency.
- D-010: MalCore imports only Foundation. All grading, choice selection, queue and schedule decisions are pure functions. Tests inject timestamps and seeded randomness.
- D-011: SQLite via the system C library, serialized on the main actor for this local app. JSON domain payloads are stored in separate content/state/event tables. Versioned schema and event scheduler version support future migration.
- D-012: Backups use SQLite's backup API and finish with DELETE journal mode so a read-only backup needs no WAL/SHM sidecars. This fixed DEF-001 caught by integration tests.
- D-013: The initial scheduler is the explicitly specified transparent algorithm, not FSRS. Changes require a new scheduler version and regression fixtures.
- D-014: Learning-pool limits count all stored learning/relearning cards for a track, including deselected banks/categories; settings explain this. No progress is deleted when filtering.
- D-015: Retry spacing yields to available alternative cards. With no alternatives, minimum time still applies. The immediately previous sense remains excluded until an explicit Check again when idle.
- D-016: The 50-card batch counts submitted answers in the current session; it is a pause point, not a daily limit. Pool sizes and schedules survive restart; session batch counters do not.
- D-017: YAML entries use bank-namespaced stable IDs; do not regenerate published IDs or move entries between namespaces. Semantic replacements receive new IDs. The first content manifest freezes assignments for later editorial updates.
- D-018: Dataset matching is not linguistic verification. Bundled candidate vocabulary remains draft until sense, aliases, labels and forms are checked. No silent promotion to verified based on automated schema checks.
- D-019: “Accept my answer” replaces the last wrong grade transactionally, retaining an undone audit record. Saving an alias is part of that transaction. Undoing the corrected grade does not delete an explicitly saved alias.
- D-020: Mode/filter changes exclude the currently presented sense, even if ungraded. Source attribution stays in the bank browser; study feedback shows usage notes only.
- D-021: Retired entries retain history but do not count against the active learning pool. Still-active entries in deselected banks/categories do count.
- D-022: Native field editor captures marked-text state at the beginning of Return handling; both pre-event and current composition states prevent submission. Repeated study keys do not cascade grades.
- D-023: Imported IDs cannot change bank ownership, including when bank namespaces are nested. The `mal` root is also reserved.
- D-024: Package into a temporary staging directory, verify the signature, then publish. Retain the previous app for rollback. Never overwrite a working package with a partially built one.

## User feedback — 2026-09-12

- D-025: Increase multiple-choice words to 30 points for beginner Hangul readability; preserve wrapping rather than shrinking long answers.
- D-026: Supersedes the hard-cap interpretation in D-014/D-021. The learning pool is a mixing target: if no eligible review is ready, introduce another unseen word regardless of pool size. Existing due dates, graduation requirements and independent tracks remain intact. When the pool is full and reviews are ready, review first.
- D-027: Supersedes D-016. Remove automatic 50-answer batch pauses and the batch-size setting. Retain the stored reviewBatch field only for settings/backup compatibility.
- D-028: Incorrect-answer feedback assumes the vocabulary is right: show Incorrect, the submitted answer, the correct answer and Continue. Replace the disabled choice grid with feedback so Continue remains easy to reach. Put override/alias actions in a small Answer options menu.

## Choice numbering feedback — 2026-09-14

- D-029: Display choices in two explicit columns, numbered top to bottom then continuing in the next column. Use 28-point semibold, primary-color number labels. Ten-choice mode retains 0 as the tenth keyboard key.
- D-030: Choice button actions read the current answer by index; rebuild shortcut controls when the choice list changes to avoid reusing bindings across cards.

- D-031 (2026-09-14): Supersedes D-029's two-column layout. Use one full-width column and default to five choices to reduce truncation. On first launch after this change, set existing installations to five once; retain other settings and all learning history. A persisted optional marker preserves subsequent manual choice-count changes and decodes older backups.

- D-032: Tighten study chrome instead of reducing readable type: 10-point main/card spacing, 16-point vertical outer padding, compact feedback footer, no redundant spacer below the scroll view. Choice buttons use a plain style with an explicit full-width background and unlimited wrapping, avoiding the native bordered button's single-line label treatment. Keep scrolling available for unusually long answers and smaller windows.
