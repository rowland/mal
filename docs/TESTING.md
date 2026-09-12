# Test plan and evidence

## Automated

Run `swift test`. Swift Testing prints an initial XCTest compatibility line saying zero tests, followed by the actual Swift Testing results. Record the final Swift Testing count, not the compatibility line.

- MalCore: accepted forms, strict rejection, NFC, English normalization, explicit aliases, sense cues; choice counts 4/6/8/10, synonym exclusion in both directions, duplicate display answers, POS preference, full bank distractor pool; graduation/failure/relearning, mode-specific intervals, history cap, independent tracks, recognized-first introduction, global pool limits, filtering, queue priority/cadence, clock rollback, retry spacing.
- MalStorage: atomic validation/import, version checks, idempotence, retirement/reactivation without state loss, grade/undo/restart, atomic override/alias, four independent tracks, backup round trip and corrupt-file rejection, schema migration and future-version rejection.
- Content: all five banks parse; exactly 500 entries each; globally unique IDs and lemmas; source links present. This verifies structure, not Korean correctness.

Use `swift run mal-bank --built-in --release Sources/MalApp/Resources/Banks/*.yaml` for the separate linguistic release gate. It must currently fail because verification is incomplete.

## Manual acceptance script

Use a disposable data directory. Do not reset the user's normal database.

| ID | Action | Expected result |
|---|---|---|
| UI-01 | Launch packaged app, resize to minimum, inspect light/dark mode | Legible native window; controls and eight choices fit; all five banks listed. |
| UI-02 | Answer multiple choice using number keys | Correct immediately advances; previous feedback remains; exactly one grade per deliberate keypress. |
| UI-03 | Select a wrong choice, Return | Feedback pauses; Return advances; no second grade for the same card. |
| UI-04 | Undo, then answer again | Prior state restored; original attempt retained as undone; corrected attempt active. |
| UI-05 | Switch both direction and answer mode | Distinct progress; no automatic graduation transfer or immediate same-sense repeat. |
| UI-06 | Enable macOS 2-Set Korean keyboard; compose a word and press Return | First Return commits composition only; a subsequent Return submits. Test consonant/vowel recomposition and backspace. |
| UI-07 | Type incorrect answer, open Answer options, choose Count as correct and remember this answer | Wrong grade replaced atomically; alias accepted in future. |
| UI-08 | Switch POS filters and bank selections | Only eligible targets; progress retained; distractors can be outside active rotation. |
| UI-09 | Set 4/6/8/10 choices, inspect keyboard labels | Requested count or clear small-bank explanation; no duplicate correct alternatives. |
| UI-10 | Pronounce with/without Korean voice installed | Speech or actionable voice-install message; study unaffected. |
| UI-11 | Import sample bank twice; edit with higher version | First import counts additions, second no-op; update preserves progress. |
| UI-12 | Back up, answer cards, restore | Content, settings, aliases and progress match backup; automatic pre-restore copy retained. |
| UI-13 | Quit while card is unanswered; relaunch | No failure recorded. Settings and graded progress preserved. |
| UI-14 | Hold a choice key/Return and type rapidly | No unintended cascading grades; record hardware-repeat issues. |
| UI-15 | Answer 120 words correctly in a row | New words continue beyond the pool target and 50 answers; due reviews resume when ready. |

## Evidence ledger

- 2026-09-12: Initial debug build compiled on Xcode 26.6 / Swift 6.3.3, macOS 26.5.2 ARM64.
- 2026-09-12: Initial suite caught DEF-001 (read-only WAL backup restore); fixed by standalone export and confirmed with regression test.
- 2026-09-12: Expanded initial suite: 20 tests passed, including 2,500-entry structural validation. Further migration tests added afterward; see STATUS.md for final run.
- User acceptance: not yet performed. Do not mark manual tests passed based on unit tests.
- 2026-09-12: Migration-expanded suite: 24 tests passed. Native smoke test confirmed launch, eight choices, correct/wrong answer flow, undo, independent write-in, Hangul paste/submission, library opening and Korean search. Actual IME and user acceptance remain untested.
- 2026-09-12 final: **25 tests passed**. Optimized app package and strict code-signature verification passed. Repeat packaging permission failure (DEF-003) fixed and verified. Sample custom-bank validation passed.
- 2026-09-12 continuation: **31 tests passed**, including AppKit marked-text preservation, composition/held-key guards, retired-card capacity, nested-namespace ownership, and reverse-cue leakage.
- Native UI: sample YAML import reports 2 added; native backup reports saved; restoring the test backup reports restored and retains selected banks/progress. Actual Korean input-method composition remains open.
- Refined packaged app relaunched with isolated data; the custom AnswerEditor accepted `물` on Return and immediately advanced to the next card. This still does not substitute for testing a real Korean IME composition session.
