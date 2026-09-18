# Mal implementation status

Last updated: 2026-09-16. This is the handoff entry point. Read REQUIREMENTS.md and DECISIONS.md before changing behavior.

## Delivered development build

- SwiftUI app with all four study combinations, five-choice default and 4/5/6/8/10 settings, full-bank distractors, part-of-speech filters, write-in field, immediate correct advancement, paused errors, override/alias and undo.
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

## Wrong-answer presentation — 2026-09-14

- Replaced the gray error slab with a labeled correct-answer panel, a readable separate submitted answer, and a larger Continue action with Return hint. Current prompt and pronunciation remain in place.
- Removed redundant footer error while paused. Moved correction commands into a labeled secondary Grading options menu beside Undo. No grading/scheduling/persistence changes.
- Next acceptance: exercise the wrong-answer manual script in both modes/directions, with long answers and dark appearance. Visual acceptance remains pending; no new unit tests for this UI-only change.

- Validation: release build and signature verification passed; `git diff --check` passed.

## Optional hints and ambiguous reverse prompts — 2026-09-14

- Korean-to-English prompts now omit English cues entirely, with Show hint available on demand and cue disclosure after an incorrect answer. English-to-Korean context stays visible.
- Pure prompt-answer rules accept other catalogued meanings of the same lemma/POS across installed banks, and choice construction excludes their synonyms even outside selected banks. Only the presented sense receives progress. No content IDs or stored history changed.
- Validation: 34 tests passed via `swift test --scratch-path /tmp/mal-five-choice-tests`, including new ambiguous-meaning/distractor coverage and updated cue assertions. Release build and signature verification passed.
- Next: user acceptance of the optional-hint flow. Existing draft vocabulary still requires linguistic review; this change uses explicit stored meanings and does not infer new ones.

## Automatic pronunciation — 2026-09-14

- Added a default-off Auto checkbox beside the speaker, persisted in settings with backward-compatible optional decoding. Toggle saves without changing the card or recording another presentation.
- Korean-to-English speaks on new-card presentation (or enabling Auto). English-to-Korean speaks the selected/submitted answer, including incorrect responses, without revealing the next answer. Manual speaker remains available.
- Automatic missing-voice feedback is nonmodal. Rapid requests replace speech; turning Auto off stops it.
- Validation: 35 tests passed in a fresh scratch build, including pure pronunciation timing rules. Extended backup preference coverage to include Auto and reran that test successfully. Release build/signature and diff checks passed.
- Next: manual listening test with installed Korean voices, keyboard choices, write-in, rapid answers, and restart. Audio/UI acceptance remains pending.

## Spoken correction — 2026-09-14

- Incorrect English-to-Korean automatic speech now queues the submitted word as a question, then the correct lemma after a 0.35-second pause. Auto-off and reverse-direction behavior unchanged. Both multiple-choice and write-in use the pure sequence rule.
- Validation: 36 tests passed, including correction order, correct answers, disabled Auto and reverse-direction exclusion. Release app and signature verification passed; diff check passed.
- Next: listen with the installed Korean voice to assess question intonation and pause length. Actual acoustic acceptance remains pending; question punctuation is interpreted by the system voice. No stored progress changes.

## Actual Korean form practice — 2026-09-14

- Added the form selector, defaulting to everyday polite on first upgraded launch. Casual, formal polite, plain statement, noun-modifying, subject-honorific polite/formal, and legacy Dictionary / any answer are available. Focused Korean grading requires the selected labeled category. Korean prompts, distractors, feedback and speech all use the displayed form.
- Independent category × direction × mode progress; dictionary mastery never graduates a form track. Ordinary nouns/adverbs keep their base track. Missing listed forms are skipped with a visible count. Labeled variants within a category share one schedule and are randomized for presentation.
- SQLite version 2 uses optional stable category keys. A v1 pre-migration backup is created before updating the version. Old history and keys remain intact; v1/v2 restores, restart and undo are covered. Earlier builds reject the upgraded database. YAML v1 needs no structural change.
- Corrected 12 erroneous honorific labels in three Novice entries (contentVersion 4), preserving IDs/status. Coverage audit: 830 predicates total; 827 have casual/polite/formal-polite and attributive forms, 805 have plain statements, 820 have the two exposed honorific styles. All 159 Novice predicates have everyday-polite forms. Exact missing lists: form-coverage.json, reproducible with scripts/audit-forms.py. This is coverage, not linguistic verification.
- Tests: 44 passed, including explicit form selection, irregulars/variants, strict grading, noun identity, focused choices, recognized-first isolation, missing-form exclusion, legacy decoding, version-1 migration, backup/restore and undo. Final rerun/build results below.
- Native UI smoke succeeded in a disposable database: polite choices and reverse prompts, formal category switch, rejection of dictionary write-in, Undo and correct-form acceptance. Five choices fit the QA window. Screenshots/AX were inspected; this is distinct from user acceptance.
- Remaining: complete linguistic verification of draft forms (including lexical honorific substitutions and sense-dependent naturalness), fill missing listed categories, and exercise actual voices/IME. Present affirmative practice is now implemented; tense, negation, commands, questions and connective forms are future scope. No mixed-category scheduler is included; choose categories manually.

- Final regression addition handles identical conjugations from different lemmas, including exclusion of their English synonyms. Final suite: **45 tests passed**. Optimized app packaging and signature verification passed. Earlier interim compile errors (SwiftUI FormStyle name collision and a test-file edit error) were corrected before this final run.

## Teach new cards before quizzing — 2026-09-16

- New queue selections display Korean form and English meanings first, including the lemma for inflected forms and sense cue when present. Continue begins the same quiz without recording an answer. Auto speaks the introduction in either direction. Existing graded tracks retain their normal review flow. No database/content migration or progress reset.
- Native smoke verified introduction, numeric-input guard, Return transition without grading, correct answer, and introduction of the next word. Tested in a disposable database; user acceptance remains separate.
- Validation: **46 tests passed**, including a presentation/restart regression proving no answer history, accuracy or graduation is created before grading. Release build/signature verification and diff check passed.
- Next: user testing of introductions in normal study, both directions/modes and Auto pronunciation; existing content/IME backlog remains open.

## Early reinforcement before new vocabulary — 2026-09-16

- Root cause: the first successful answer waited ten minutes, while the continuous-study fallback introduced unseen words throughout that gap.
- Scheduler v2 adds a persisted three-intervening-answer reinforcement trigger after first success. Due reinforcement precedes new insertion; due relearning/reviews retain priority. A short correct repeat keeps step 1 and schedules the timed ten-minute check. The one-day check, three-day first review, accuracy-based growing intervals and failure behavior remain. Waiting ten minutes naturally can satisfy the timed step without a separate short repeat.
- Small banks can repeat earlier when no alternatives remain, still excluding the previous sense. Existing stored due dates/progress are preserved; newly graded first successes receive reinforcement. No schema migration/reset. Introductions do not count as answers.
- Validation: **49 tests passed** in a fresh scratch build. Four direction/mode simulations now introduce 120 words and perform 120 reinforcement recalls, beginning with a repeat on the fifth answer, without artificial caps or premature graduation. Timing, failure, restart/undo, and existing review/clock tests pass. Release build/signature verification passed.
- Next: user study acceptance of the cadence, especially slow sessions, failures and small banks. Native layout unchanged except explanatory settings text; no new UI smoke run for this rules change.


## Dual-clock iteration — 2026-09-16

Implemented scheduler v3 and SQLite v3: granular time/answer spacing, perpetual maintenance, lapse recovery, four-word first-repeat capacity, persisted local clocks, undo and backed-up migration. Status tooltips explain due/recognized; previous-answer feedback includes the next date or answer distance. Settings exposes first-repeat capacity.

Automated verification: `swift test --scratch-path /tmp/mal-dual-clock-tests`: **53 tests passed**, including four speed-run cases, dual deadlines, clock rollback, caps, track isolation, legacy migration, undo, restart and backup restoration. Build verification recorded below. No personal database was reset or used for automated tests.

Manual acceptance pending (separate from automated results):
1. In a temporary data directory, answer rapidly; the first word should recur after three intervening answers, then after eight. At most four words await the early repeat.
2. Switch direction, form and answer mode; check that unrelated practice does not consume a card's answer deadline. Nouns share schedules, attached to their last-used style clock.
3. Wait past a short deadline without answering; Check again should make it due. Recognized words remain eligible for periodic review.
4. Make a mistake, Continue, undo, restart, and confirm the displayed next check and history. Verify five wrapped choices still fit the study window with the new footer line.
5. Use a disposable v2 database copy: open, confirm backup, progress and due dates; restore an older backup and repeat.

Next concrete action: user acceptance of the pacing and footer layout; adjust defaults from actual study feedback. Remaining release gates are unchanged: independent vocabulary verification and full Korean IME/UI acceptance. No manual UI acceptance is claimed for this iteration.

Build verification: `./scripts/build-app.sh` succeeded; release executable and ad-hoc signature verified; published `build/Mal.app`. Final repeat of the suite: 53 tests passed (0 failures). `git diff --check` passed. Manual user testing remains pending.

## Due-first introductions — 2026-09-16

User observed a new introduction with 59 cards due. Removed the five-answer exception: eligible due learning/relearning/maintenance cards now always precede unseen cards. New introductions resume when no eligible cards are due and first-repeat capacity permits. Scheduling intervals, history and database format are unchanged.

Verification: `swift test --scratch-path /tmp/mal-dual-clock-tests` passed **54 tests**, including six phase/clock combinations asserting due priority and resumption, plus all four speed-run cases. `./scripts/build-app.sh` succeeded and published `build/Mal.app`; `git diff --check` passed. No personal data touched. Manual user acceptance pending: reopen the app with a due backlog, answer beyond five cards and confirm no introduction until eligible due cards clear; then confirm introductions resume. Next action: user verification of that pacing. Existing vocabulary/IME release gates remain open.

## Explicit unsuccessful recall — 2026-09-17

Added I don’t know below choices/write-in, with ⌘K. Reveals actual Korean form, meanings, cue and dictionary form where applicable; keeps manual pronunciation and honors Auto. Continue advances and excludes this sense from the next selection. Uses normal failure spacing (30 seconds or three answers), distinct history label, and existing atomic grade/undo. Progress format unchanged.

Automated: `swift test --scratch-path /tmp/mal-dual-clock-tests` passed **55 tests**. New storage regression verifies failure timing, accuracy/count, distinct history across restart, and exact schedule/counter restoration by undo. `git diff --check` passed. Manual/UI acceptance remains pending: in both directions and modes, activate by button and ⌘K; verify one recorded failure, readable introduction, Return advances, Auto/manual pronunciation, history label and Undo. Check a single-word bank shows a waiting state rather than an immediate quiz. No personal database used.

Next action: user acceptance of button placement, shortcut with Korean IME active, and reintroduction pacing. Vocabulary verification and broader IME acceptance remain open.

Build: `./scripts/build-app.sh` succeeded, publishing the signed local `build/Mal.app`. Native manual smoke not performed in this iteration; the script above is pending user acceptance.

## Korean speech input — 2026-09-17

Implemented Speak Korean / Stop (⌘⇧R) for English→Korean write-in. Uses macOS 26 SpeechAnalyzer/SpeechTranscriber; no cloud recognition. Drafts remain editable after stopping and require Return to grade. Auto playback is suppressed while active. Card/mode transitions, undo, unknown-word action, sheets and app deactivation cancel capture and reject late results. Recording is bounded to 20 seconds; finalization to five. Explicit first-use model download and microphone permission; microphone usage description included in app packaging. No schema/progress changes.

Read-only capability probes on this Mac: legacy ko-KR recognizer available=true, supportsOnDeviceRecognition=false; newer SpeechTranscriber lists ko_KR among supported locales, but installed locales were English only. Therefore an Apple Korean model download is necessary before live use. The model has not been downloaded or a microphone recording attempted during this iteration.

Automated: `swift test --scratch-path /tmp/mal-speech-tests`: **58 tests passed**, including stale-result rejection, draft retention/cleanup, and stereo 48 kHz→mono 16 kHz conversion into independently owned buffers. Existing grading/storage/IME tests passed. No compiler warnings in the final test run. These tests do not verify speech accuracy or actual microphone capture.

Manual acceptance script: choose English→Korean + Write-in, continue an introduction, click Speak Korean. If prompted, use Download Korean speech model (internet required once), then retry. Allow microphone access, speak the displayed category of Korean answer, Stop (or ⌘⇧R), edit as necessary, and Return to grade. Test denial, no speech, permission cancellation, stopping during setup, switching cards/modes while listening, 20-second auto-stop, and use with network disabled after model installation. Confirm no grade is recorded until submission and no audio playback contaminates listening. Check Korean IME composition after dictation.

Next action: install the model through Mal and perform live microphone/offline acceptance. Speech accuracy and device/permission handling remain unverified end-to-end; existing vocabulary verification and broader UI/IME acceptance gates remain open.

Build verification: `./scripts/build-app.sh` succeeded and published the signed local `build/Mal.app`; final `git diff --check` passed. Native smoke used `/tmp/Mal Speech QA.app` (distinct bundle ID) with `MAL_DATA_DIRECTORY=/tmp/mal-speech-qa-data`: switched to English→Korean write-in, continued introduction, confirmed Speak Korean, used ⌘⇧R, confirmed Download Korean speech model and local-processing guidance, and confirmed answer field remained enabled with zero grades. Closed test app. No download or microphone capture performed; user data untouched.

## Persistent spoken practice — 2026-09-17

Speak Korean is now a saved input preference within English→Korean write-in. New quiz cards listen automatically; introduction/correction audio finishes first. Finalized nonempty utterances submit automatically. Return submits the visible transcript immediately, cancels late recognition results, and does not require Stop. Escape opens the current draft for editing while retaining speech for following cards. Write-in disables the preference. ⌘⇧R edits/resumes; no per-card button is required. Undo opens editing rather than recording. New optional preference preserves legacy settings/backups.

Verification: `swift test --scratch-path /tmp/mal-speech-tests` passed **60 tests**. Added Return/Escape, repeat/modifier/IME exclusion and late-final-result tests; existing settings backup/restore test now includes spoken preference. `./scripts/build-app.sh` succeeded and published `build/Mal.app`; `git diff --check` passed. No live microphone or new native UI acceptance performed this iteration.

Next concrete action/manual script: select Speak Korean once and study several cards. Verify automatic start after introductions and correct responses, no recording during correction speech, engine-finalized automatic submission, and immediate Return submission before finalization. Escape should enable correction, Return grade that edit, and next quiz listen again. Confirm explicit Write-in persists across cards/restart, repeated Return cannot cascade grades, and missing model/permission failure remains recoverable by selecting Write-in. Test speech timing in actual room noise: engine finalization may lag; Return bypasses it. No custom silence threshold is claimed. Existing vocabulary and full IME release gates remain open.

## Shorter speech timeout and quiet successes — 2026-09-17

Recording timeout reduced 20→8 seconds; finalization bound 5→2 seconds. Correct answers in Speak Korean practice no longer trigger automatic answer replay. Wrong answers retain question/correct-answer audio under Auto. Introductory pronunciation and manual replay remain available; Return submission remains immediate.

Verification: `swift test --scratch-path /tmp/mal-speech-tests`: **61 tests passed**, including quiet spoken successes, spoken-error correction, Auto off, typed success audio and reverse prompts. `git diff --check` passed. Live microphone timing/audio acceptance was not performed; next action is user verification of the shorter cutoff and silent successes during normal study. Existing vocabulary/IME release gates remain open.

Build: `./scripts/build-app.sh` succeeded and published the signed local `build/Mal.app`.

## Five-second speech timeout — 2026-09-17

Reduced recording timeout 8→5 seconds at user request. Finalization remains bounded at 2 seconds; Return still submits immediately. Release build via `./scripts/build-app.sh` and `git diff --check` passed. Unit suite not rerun for this single timing-constant change; previous suite remains 61 passing tests. Live microphone timing acceptance pending. Next action: user checks whether five seconds accommodates recall/speaking while reducing waiting. No progress or schema changes; existing release gates remain open.

## Automatic answer-field input sources

Added native focus-scoped Korean/English input switching to the custom answer editor. Includes spoken-answer Escape editing, window focus loss/restoration, disabled fields and view dismantling. Existing matching Korean layouts are retained; manual changes survive SwiftUI refreshes. Only enabled/selectable sources are used, and missing languages are a no-op. No user database changes.

Verification: `swift test --scratch-path /tmp/mal-speech-tests`: **63 tests passed**. Two injected-source tests cover both language directions, prior-source restoration, manual Korean layout preference, same-focus overrides, composition guards and unavailable language fallback. Existing IME Return tests pass. `./scripts/build-app.sh` succeeded and published signed `build/Mal.app`; `git diff --check` passed. Actual input-menu switching and physical Korean composition are not yet manually verified.

Next action/manual acceptance: with Korean enabled in macOS, focus a Korean write-in answer and type Hangul; commit a syllable with Return without submitting, then submit separately. Repeat for English answers and Escape editing in spoken practice. Manually choose a different layout while editing and confirm it remains selected until focus leaves. Switch to another app, open history, and switch back; verify prior source is restored and Mal chooses the appropriate source on refocus. Repeat without an enabled Korean source to confirm normal typing remains available. Existing content verification and live-speech acceptance gates remain open.

## English gloss grading and remembered answers

User reported “meet” rejected for 만나요 and the remember-answer option missing. Confirmed source data stores “meet; to see (someone)” as a single English string; Grader previously required that complete string. Added conservative top-level semicolon alternatives and predicate infinitive-prefix handling, shared by grading and distractor exclusion. Restored remember-answer availability for Korean→English even with focused Korean form practice. No content bank or database migration; prior history remains unchanged.

Verification: `swift test --scratch-path /tmp/mal-speech-tests`: **66 tests passed**. Includes qualifiers/negative false positives, semicolons inside parentheses, comma preservation, distractor synonym exclusion, English alias eligibility across all form categories, actual Novice 만나다 accepting “meet”, and saved English alias override surviving restart with correct totals. `git diff --check` passed. Native menu acceptance not performed this iteration.

Next action/manual script: reopen Mal, practice Korean→English write-in with Everyday polite, answer 만나요 with “meet”; verify immediate success. On a different incorrect English response, confirm Grading options includes Count as correct and remember this answer, use it, and verify acceptance after restart. Comma-packed or heavily qualified definitions may still need explicit personal aliases or future curated content fixes; broad punctuation stripping is intentionally avoided to prevent false positives. Existing linguistic verification/IME/live-speech release gates remain open.

Build: `./scripts/build-app.sh` succeeded, publishing signed `build/Mal.app`.
