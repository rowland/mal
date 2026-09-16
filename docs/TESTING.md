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

### Choice numbering regression

Use an isolated `MAL_DATA_DIRECTORY` for destructive QA. At 4, 6, 8 and 10 choices, verify numbering runs down the left column then the right; 0 selects the tenth answer. Across successive cards and direction changes, press each displayed number and compare the recorded submitted answer in History with that choice. Check an odd-sized custom bank, legibility at minimum window size, and that held keys do not answer subsequent cards. Record user/UI results separately from build verification.

### Single-column acceptance (supersedes two-column expectations above)

Confirm five choices appear on first updated launch, numbered 1–5 in a single column. Check long English and Korean answers wrap at minimum window width and all five keyboard keys select the displayed answer. Change choice count, restart, and verify the choice-count preference persists. Personal progress must remain intact.

### Compact layout regression

At approximately 1050 × 750 window size, verify all five short choices are visible without scrolling; repeat with one long two-line English choice. Confirm long labels wrap without ellipses, full rows remain clickable, number shortcuts work, and previous-answer feedback/Undo remain visible. At smaller sizes or with many multiline answers, verify scrolling reaches every option.

### Wrong-answer feedback revision

In both directions and answer modes, deliberately answer incorrectly. Confirm the prompt stays visible; Correct answer and Your answer are clearly labeled and wrap for long text; Continue and Return advance once. Check pronunciation, footer Undo, and both Grading options actions still work. Verify the footer does not repeat the current error and normal previous-answer feedback returns after continuing. Check light/dark appearance and a narrow window.

### Optional reverse hints

Check 없다 displays without its English cue. Show hint should reveal it without submitting; the next card and an undone card should start hidden. Wrong answers reveal the cue. Switch direction and confirm English-to-Korean context remains visible. With a custom bank containing two senses of one lemma/POS, verify either curated English meaning grades correctly but only the presented track changes; neither alternate meaning nor its synonyms appear as distractors.

### Automatic pronunciation

Enable Auto beside the speaker: Korean-to-English should speak the current/new prompt once; manual speaker replays it. English-to-Korean must stay silent until selection/submission, then speak that answer even when wrong. Try keyboard choices, typed answers, rapid advancement, both directions, toggling off during speech, and restart/backup restoration of the preference. No installed voice must not block automatic study.

### Spoken correction

With Auto on in English-to-Korean, choose a wrong answer: hear the selected Korean word as a question, a short pause, then the correct lemma. Repeat in write-in mode. Confirm correct answers speak once, Auto off is silent, and manual replay/toggling off cancels the queued correction. Assess question intonation with the installed Korean voice; punctuation-based prosody varies by voice.

### Form practice acceptance

1. Quit earlier builds, launch the new app, and confirm Everyday polite is selected. Existing vocabulary history remains; predicate form tracks start fresh. A v1 database receives a pre-migration backup beside it.
2. With action verbs selected, confirm Korean choices are actual polite forms, e.g. 가요; switching direction presents conjugated Korean. All five choices should fit at the usual window size.
3. Switch to casual/formal/plain/attributive/honorific categories. Check labels, eligible words and new progress pools; missing-category counts must not silently fall back to dictionary forms.
4. In formal English-to-Korean write-in, enter 오다 for come: reject it and show 옵니다. Undo, then enter 옵니다: accept. Repeat with equivalent listed variants and an irregular predicate. Paste testing is separate from IME acceptance.
5. Auto and manual speech should pronounce the presented/selected form; wrong-answer correction should speak the correct form rather than the lemma.
6. Return to Dictionary / any answer to see original vocabulary progress and permissive listed-form grading. Noun progress is shared across categories. Check history shows form identity, and restart restores the selected style.
7. Back up form progress, restore a pre-upgrade v1 backup, then restore the v2 backup. Check independent states, overrides and undo. Never test this against personal progress without a separate backup.

Automated UI smoke (2026-09-14): isolated `/tmp/Mal Forms QA.app` with `MAL_DATA_DIRECTORY=/tmp/mal-forms-ui`. Verified five visible polite choices, numeric correct advancement, reverse 가요 prompt, switching to formal 옵니다, formal write-in rejecting 오다, Undo retaining the category, then accepting 옵니다. Closed the disposable app. No personal database was used. Broader listening/IME testing remains open.

### New-card introductions

In both directions and answer modes, introduce an unseen track. Verify Korean form, English meanings, optional lemma/cue, replay and Continue. Number keys must not grade; Return reveals the same quiz without changing accuracy or learning counts. First submitted answer starts the first learning step. Restart before grading should reintroduce the word; already graded reviews should quiz directly. Check held Return, mode/form switching, and Undo.

Native smoke, 2026-09-16: `/tmp/Mal Introduction QA.app`, data `/tmp/mal-introduction-ui`. Verified 집 → house/home introduction, ignored numeric key, Return to unchanged house quiz with zero learning count, correct numeric answer, then 물 → water introduction. Screenshot inspected; closed QA copy. No personal database used.
