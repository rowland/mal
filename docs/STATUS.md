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

Keep commits focused. Update this status file after each iteration with exact checks run, open defects and the next concrete action. Never erase user progress for convenience; test against temporary stores. GitHub remote: https://github.com/rowland/mal (public), with main tracking origin/main. Project tracking remains in repository Markdown; no external issue workflow is configured.

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

## Reconciled study counts — 2026-09-18

Confirmed status bug: recognized always counted multiple-choice maintenance, even in write-in mode. Future write-in maintenance therefore vanished from current-mode categories. Status now shows in play, learning, in review and due, all for the selected track and filters. In play = learning + in review; due is explicitly an overlapping subset. Current ungraded introduction counts as learning without a persisted grade. No scheduling/database changes.

Automated: `swift test --scratch-path /tmp/mal-speech-tests`: **68 tests passed**, including future maintenance, relearning, both due clocks, mode isolation, filter preservation and introduction double-count prevention. `git diff --check` passed. Native layout/user acceptance remains pending.

Next action: user verifies totals in Korean→English write-in, switches modes/filters and checks in play equals learning plus in review. Due should change independently as deadlines pass. This fixes displayed accounting, not a loss of stored progress. Existing content/IME/live-speech release gates remain open.

Build: `./scripts/build-app.sh` succeeded and published signed `build/Mal.app`.

## Speech recognition ambiguity tolerance — 2026-09-18

Added pure SpokenGrader and requested recognition alternatives. Exact accepted alternatives count correct; one initial plain/tense consonant substitution can also pass with compact interpreted/heard feedback. Other near matches (one Hangul syllable, at most two jamo changes) open an ungraded confirmation panel: I said [candidate], Try again, Count incorrect, Escape editing. Actual dictation provenance gates tolerance; Escape editing and normal typed grading remain exact. No persistent content aliases, schema changes or personal database edits.

Verification: `swift test --scratch-path /tmp/mal-speech-tests`: **70 tests passed**, including recognition alternatives, all five plain/tense pairs, 한국과/한국어 confirmation, 어/아 confirmation, negation/tense/blank rejection, exact-match priority and unchanged typed grading. `./scripts/build-app.sh` succeeded and published signed `build/Mal.app`; `git diff --check` passed. Live recognition alternative quality and confirmation UI acceptance remain pending.

Next action/manual script: in English→Korean Speak Korean, try a known plain/tense confusion and check Accepted as… feedback; try 한국어 and inspect any recognition-check panel for 한국과. Try again must leave history/counts unchanged, explicit confirmation must create one successful grade, Count incorrect one failure, and Undo restore prior progress. Escape should enable exact text correction with no stale speech result overwriting it. Confirm new cards clear prior alternatives/pending prompts. Existing content verification and broader speech/IME acceptance gates remain open.

## Unmatched speech does not imply learner failure — 2026-09-18

User screenshot: 입어요 expected, 이뻐요 transcribed and automatically marked wrong. Previous comparison allowed only a single changed syllable; this example changes two. Updated SpokenGrader to route every nonempty unmatched transcript to the existing ungraded recognition-check panel, rather than widening automatic acceptance. I said [form] records success; Try again records nothing; Count incorrect records failure; Escape opens exact editing. Original heard text is retained in graded history. No existing grades were rewritten.

Verification: `swift test --scratch-path /tmp/mal-speech-tests`: **71 tests passed**. Regression explicitly covers 입어요/이뻐요, whitespace/punctuation/larger mismatches, displayed-form preference, and strict typed rejection. Negated/past-tense speech mismatches now require confirmation rather than being silently accepted or failed. `git diff --check` passed. Live recognition/confirmation UI acceptance remains pending.

Next action: repeat the reported spoken example; verify no Incorrect screen or history/counter change precedes your decision. Confirming must create one correct grade, retry none, and Count incorrect one failure. Apple transcription quality is still unresolved; this change protects grading from it. Existing linguistic/IME/live-speech acceptance gates remain open.

Build: `./scripts/build-app.sh` succeeded, publishing signed `build/Mal.app`.

## Symmetric Korean answers for ambiguous English prompts — 2026-09-18

Investigated red: Novice 빨갛다 already accepted 붉다 variants, but General 붉다 did not reciprocate. Added same-English/POS/cue equivalence in FormPractice, with selected style preserved. Both targets now accept 빨개요/붉어요 in polite practice and 빨간/붉은 in attributive practice. Multiple-choice exclusion uses the expanded accepted set. Added Also accepted to focused Korean introductions/corrections to clarify randomized example forms.

Verification: `swift test --scratch-path /tmp/mal-speech-tests`: **73 tests passed**, including both actual bank entries across polite/attributive forms, rejection of incorrect style, and separation of wear-a-hat/wear-clothes/POS. `git diff --check` passed. No bank data, IDs, verification status or user progress changed. Native Also accepted layout acceptance pending.

Next action: test red in English→Korean polite mode with both 빨개요 and 붉어요; verify either passes regardless of the displayed correction/example. Check differing object cues continue to enforce the correct sense. Existing independent content, speech and IME release gates remain open.

Build: `./scripts/build-app.sh` succeeded after the alternate-answer UI addition and published signed `build/Mal.app`.

## Confirm the synonym actually spoken — 2026-09-18

Fixed recognition-check UI offering only 빨개요 when 붉어요 was equally accepted. Pending confirmation now retains all accepted forms, and the panel provides a button for each. Selection is validated against the pending set; feedback uses the confirmed form, history retains the heard transcript, and no grade occurs before selection. Retry/Count incorrect/Escape behaviors remain.

Verification: `swift test --scratch-path /tmp/mal-speech-tests`: **74 tests passed**, including the exact 불까요→red scenario, both 빨개요/붉어요 confirmation options, uniqueness and invalid preferred-form handling. `git diff --check` passed. Native layout/live recognition acceptance pending. Next action: repeat the reported case and confirm I said 붉어요 is available and records one success without requiring spelling edits. Existing release gates remain open.

Build: `./scripts/build-app.sh` succeeded and published signed `build/Mal.app`.

## Wait for speech, finish after quiet — 2026-09-18

Removed five-second recording cutoff. Listening stays ready during thinking, reports activity once detected, and finalizes after approximately 0.8 seconds of quiet with a nonempty transcript. Final transcript segments no longer individually trigger submission while speech may continue. Return still submits the visible draft immediately; Escape edits; error/ambiguity handling unchanged. Two-second finalization bound remains. Energy/noise-floor detection is heuristic and needs microphone-specific acceptance.

Verification: `swift test --scratch-path /tmp/mal-speech-tests`: **77 tests passed**, including 60 seconds of thinking silence, brief pauses/resumed speech, post-speech quiet, noise without transcription, invalid meter values and planar/interleaved stereo metering. `git diff --check` passed. No live microphone endpoint test performed.

Next action/manual acceptance: wait longer than five seconds before speaking, then speak a word and pause; verify capture stays ready while thinking and submits/checks soon after finishing. Try multiword answers with a brief internal pause, soft speech and normal background noise. Verify Return bypasses waiting and Escape/card/app changes stop capture. Report premature cutoffs or failures to finish so sensitivity/quiet duration can be tuned. Existing vocabulary/IME/live-speech release gates remain open.

Build: `./scripts/build-app.sh` succeeded and published signed `build/Mal.app`.

## Reduce background-noise endpoint delays — 2026-09-18

Adjusted the endpoint activity threshold to account for sustained voice level, preventing substantially quieter room noise from repeatedly resetting the quiet timer. Brief clicks no longer erase accumulated quiet or raise the voice reference. First transcript evidence clears silence accumulated while thinking. Retained the 0.8-second quiet interval, indefinite thinking time, and Return submission override. No personal data or grading rules changed.

Verification: `swift test --scratch-path /tmp/mal-speech-tests`: **79 tests passed**. Regression coverage includes quieter room noise after speech, a brief loud click, resumed soft speech, and long thinking silence. `./scripts/build-app.sh` succeeded and published signed `build/Mal.app`. `git diff --check` passed. Live microphone testing has not been performed; equally loud background noise can still defeat this energy heuristic.

Next action/manual acceptance: reopen the rebuilt app and speak in the environment that produced the delayed cutoff. Check that normal room noise no longer extends capture, and that softer speech and short internal pauses are not cut off. Return remains available to submit immediately. Existing content, IME and live-speech release gates remain open.

## Progressive speech vocabulary matching — 2026-09-20 — awaiting human review

User reports recognition has worsened and requests live intersection matching rather than waiting for silence on already-valid speech. Added pure SpokenGrader.matches across primary/alternative hypotheses and the existing accepted translations. Whole words/contiguous phrases may appear among extra words; embedded substrings do not match. The live callback submits only exact intersections and cancels capture; uncertain speech retains the silence/Return confirmation path. Typed grading and personal progress are unchanged. No bank content edited.

Automated verification: `swift test --scratch-path /tmp/mal-speech-tests`: **81 tests passed**. Includes primary/alternative intersections, two red synonyms, self-correction “한국아, I mean 한국어!”, punctuation, NFC, phrase boundaries, substring rejection, and strict typed grading. Existing session-cancellation and endpoint tests pass. First sandboxed test invocation failed on compiler-cache permissions; authorized rerun passed. `./scripts/build-app.sh` succeeded, publishing signed `build/Mal.app`; `git diff --check` passed.

Human acceptance: **pending; changes intentionally uncommitted**. No actual microphone recognition/latency verdict is claimed. Next action: user quits/reopens build/Mal.app and tests English→Korean Write-in / Speak Korean:

1. Think silently, then speak a correct word. A matching live hypothesis should advance without waiting for quiet; confirm only one history entry.
2. On red, try both 빨개요 and 붉어요 in everyday polite mode.
3. On Korean/language, try “한국아, I mean 한국어!”; inspect Accepted as / heard feedback.
4. Speak an unrelated answer and pause: no early success; recognition confirmation should appear after the silence/finalization path. Return and Escape must still work.
5. Try soft speech and room noise; report whether delays persist or early matches interrupt unfinished answers. Apple may revise volatile hypotheses after the point we choose to accept; this tradeoff needs real use.

Await explicit human review before committing. Existing content/IME/live-speech release gates remain open.

## Speech latency trial — 2026-09-20 — awaiting human review

User acceptance of the progressive-matching build found several seconds of latency after speaking. Inspection found fastResults was not enabled, and analyzer preparation was deferred until input. Enabled fastResults with alternatives/volatile results and explicitly prepare the analyzer before microphone capture/Ready. Added text-free OSLog timing events (subsystem app.mal, category SpeechTiming) to distinguish preparation, audio activity, first result, endpoint/finalization and closure. No measured microphone latency improvement is claimed. Apple's faster-results mode can reduce accuracy; this remains an experiment.

Verification: `swift test --scratch-path /tmp/mal-speech-tests`: **81 tests passed**. `./scripts/build-app.sh` succeeded and published signed `build/Mal.app`. `git diff --check` passed. No changes to scheduling, database, bank data or endpoint rules this iteration. Previous progressive matching changes remain uncommitted as requested.

Next action: user quits/reopens build/Mal.app and tests several short answers after Ready appears, comparing delay and accuracy. If delay persists, inspect timing with `log show --last 10m --style compact --predicate 'subsystem == "app.mal" AND category == "SpeechTiming"'` to separate model delivery from endpoint waiting. Logs contain event names/elapsed times only. Live microphone results and human review remain pending; do not commit until accepted.

## Inspect Apple's alternatives — 2026-09-20

Human feedback: recognition speed is now acceptable. Screenshot shows 하예요 with confirmation choices 하얘요/희어요. Those buttons are accepted vocabulary, not Apple's alternative transcripts. Previously returned alternatives were overwritten with each result and not recorded, so the historical API output cannot be verified from the screenshot.

Added collapsed Apple recognition details to confirmation: latest 100 updates of the current attempt, raw primary/alternatives (including empty strings), partial/final status, elapsed time and prior finalized prefix. Text is selectable and explicitly copyable. Kept in memory only, reset at each recording; no transcript added to OSLog or storage. Grading and fast recognition settings unchanged. No new vowel tolerance rule introduced pending inspection.

Next human check: reopen build/Mal.app, reproduce white/하예요, expand Apple recognition details and copy the updates. Check whether 하얘요 appears in any raw alternative, distinguishing Apple results from Mal's accepted answer buttons. UI/live capture acceptance pending. All changes remain uncommitted pending review.

Verification: `./scripts/build-app.sh` succeeded and published signed `build/Mal.app`; `git diff --check` passed. This iteration changes diagnostic capture/UI only; rules/storage tests were not rerun (previous full suite: 81 passed). Native diagnostic disclosure/copy behavior remains to be checked with a real recognition attempt.

## Extensible speech-only rules — 2026-09-20 — awaiting review

User supplied actual API output: partial 하, partial 하예, then final alternatives 하예요., 하게요., 하이예요., 하 예요., 하에요. No 하얘요. This verifies diagnostic capture/copy through real use; user previously confirmed restored speed.

Added SpeechMatchingRule/SpeechMatchingRules in pure MalCore: versioned rule identifiers, explicit live eligibility, independent predicates and candidate/answer/rule evidence. Added vowel-pairs-v1; extracted existing plain/tense accommodation into its own rule. Exact matching takes precedence; ambiguity across rules and alternatives cannot auto-grade. Rules do not compose. The vowel rule handles the reported example live, including punctuation and NFC; it does not accept changed consonants, omitted syllables or additional word suffixes. Typed/Escape-edited grading remains strict. No database/content edits.

Verification: `swift test --scratch-path /tmp/mal-speech-tests`: **84 tests passed**, including the supplied five alternatives, both vowel pairs in both directions, multiple vowel substitutions, evidence/disabled rules, exact precedence, ambiguity across hypotheses, non-composition, negative cases and typed rejection. `./scripts/build-app.sh` succeeded and published signed build/Mal.app. `git diff --check` passed.

Next human acceptance: reopen Mal and repeat white/하얘요; Apple 하예요 should advance with Accepted as 하얘요 feedback. Confirm no renewed latency and that unrelated speech still reaches confirmation. Changes remain uncommitted pending human review.

## Live single/double consonants — 2026-09-20 — awaiting review

User reports vowel-rule behavior good so far and requests relaxed single/double consonants. Enabled the existing plain-tense-initial rule during live matching; previously it only ran at submission. All five onset pairs work bidirectionally on primary/alternatives. Exact precedence, unique-answer requirement, strict typing, and non-composition retained. Screenshot 빨아요/받아요 also changes the final consonant; it intentionally remains confirmation and is covered by a regression.

Verification: `swift test --scratch-path /tmp/mal-speech-tests`: **85 tests passed**. Added live pair/direction/alternative coverage, ambiguity and exact precedence, aspirated-consonant and suffix rejection, and reported screenshot behavior. `./scripts/build-app.sh` succeeded and published signed build/Mal.app; `git diff --check` passed. Personal data/content unchanged.

Next action: reopen the app and test a pure single/double consonant recognition substitution. Confirm immediate acceptance while 빨아요/받아요 still requires confirmation. Changes remain uncommitted for human review; no live microphone acceptance claimed this iteration.

## Contextual ㄹ/ㄷ recognition trial — 2026-09-20

Added named rieul-digeut-before-a-eo-v1 rule for a single coda ㄹ/ㄷ difference immediately before an identical 아/어-vowel syllable. An optional plain/tense onset change in that same preceding syllable explicitly covers 빨아요/받아요. This supersedes the prior screenshot rejection test. No whole-word aliases; tentative 애/에 contexts, intervening spaces, unrelated consonants/vowels and syllable additions remain excluded. User-facing commentary describes this as recognition tolerance, not accepted spelling or phonetic equivalence.

Verification: `swift test --scratch-path /tmp/mal-speech-tests`: **86 tests passed**, including screenshot, second context, symmetry, alternative hypotheses, negative contexts, ambiguity, exact precedence, rule evidence and strict typed rejection. `./scripts/build-app.sh` succeeded and published signed build/Mal.app. `git diff --check` passed. No personal data/content changes.

Next action: reopen the app and repeat receive; 빨아요 should match 받아요 when it is the unique accepted match. Evaluate false positives and live behavior; this rule deliberately tolerates a difference that can separate real words. 애/에 expansion remains deferred. All changes remain uncommitted pending human review.

## Speech checkpoint approved — 2026-09-20

User reviewed the speech iterations, reported restored speed and good progress, and explicitly requested a commit. The review gate for this checkpoint is satisfied. Commit includes progressive hypothesis matching, faster/prepared recognition, inspectable Apple results and extensible speech-only vowel/consonant rules. Latest verification remains 86 passing tests plus successful signed app build; no implementation changes since those checks. Commit-time diff whitespace check passed.

Next action: continue ordinary study and capture Apple recognition details for unresolved words; add narrowly tested rules only when supported by examples. Contextual ㅐ/ㅔ expansion, broader false-positive evaluation, and existing content/IME release gates remain open. Approval of this checkpoint does not constitute exhaustive linguistic or UI acceptance.


## GitHub repository — 2026-09-20

At the user's request, created private https://github.com/rowland/mal and pushed the existing main history. Set origin to git@github.com:rowland/mal.git and main to track origin/main. Build artifacts and personal SQLite databases remain ignored. No code changes or new test run for this repository setup; latest application verification remains 86 passing tests and successful signed build. Next action: continue project work from this repository and push reviewed commits.

## Public repository and Apache license — 2026-09-20

User authorized public GitHub visibility and Apache License 2.0. Added official LICENSE, project NOTICE, README licensing scope and bundled app copies. Original application code/documentation use Apache-2.0; vocabulary data retains CC BY-SA/source attribution and Yams retains its existing notice.

Verification: app build/signature verification succeeded; Apache-2.0.txt and Mal-NOTICE.txt confirmed in the packaged app. `git diff --check` passed. No rules/storage changes; unit suite not rerun (latest 86 passed). Next action: continue normal development on public rowland/mal, retaining the separate content licensing and verification gates.

## Bare English prompts accept cross-category translations — 2026-09-20

Removed POS restriction from English→Korean equivalence for uncued prompts. Both many entries now accept 많이 and polite 많아요; all accepts 다/모두/모든/온/온갖 across their grammatical categories. Full installed catalog already supplies answers independently of selected banks, POS filters or rotation; no scheduler/state changes needed. Per-candidate selected form and explicit sense cues remain enforced. This is shared typed/speech/choice behavior, not another recognition accommodation. No bank versions, data or progress changed.

Verification: `swift test --scratch-path /tmp/mal-speech-tests`: **87 tests passed**, including actual five-bank many/all entries, symmetry, speech intersection, selected-form exclusions and valid-answer distractor exclusion. Existing wear/sense-cue regressions pass. `./scripts/build-app.sh` succeeded and published signed build/Mal.app. `git diff --check` passed.

Next human acceptance: reopen Mal and answer many with either 많이 or 많아요, and all with any of the listed catalogued alternatives, regardless of which entry entered rotation. Verify choices have one accepted option and cued prompts remain specific. Changes left uncommitted for review; linguistic corpus verification remains open.

## Cross-category translation checkpoint approved — 2026-09-20

User reports the behavior is better and explicitly requests a commit. Review gate satisfied for this checkpoint. Latest automated verification: 87 tests passed and signed app build succeeded; no implementation changes since that run. Commit-time diff check passed. Next action: continue study and collect any remaining ambiguous-prompt examples; broader linguistic verification remains open.

## Optional parenthetical hints in English answers — 2026-09-21

User requests accepting light for light (not heavy) without per-word overrides. Added optional balanced-parenthesis omission to English dictionary-answer expansion, including nested hints, semicolon meanings and optional to. Full gloss remains displayed/accepted; hint text alone does not pass. Malformed/empty expansions are excluded. Korean answers and personal aliases remain literal; English→Korean sense equivalence retains parenthetical qualifiers.

Verification: `swift test --scratch-path /tmp/mal-speech-tests`: **88 tests passed**, including light, see (someone), nested/mid-phrase hints, malformed parentheses, empty-answer prevention, wrong qualifier rejection, strict Korean grading and protection against reverse-sense merging. `./scripts/build-app.sh` succeeded and published signed build/Mal.app. `git diff --check` passed. No data migrations or bank changes.

Next action: reopen Mal and answer a parenthetically qualified English definition with just the main word. Native study acceptance pending; changes left uncommitted for review. Existing content/IME verification gates remain open.

## Football/soccer vocabulary correction — 2026-09-21

Fixed 축구 (mal.novice.d60647b53b86ec02) storing football, (US) soccer as one indivisible answer. Explicit football/soccer alternatives now precede the retained combined gloss. Novice contentVersion raised to 5 for automatic import on launch; stable ID, history and draft verification status preserved. Parenthesis omission alone could not resolve the comma-separated alternatives.

Verification: `swift test --scratch-path /tmp/mal-speech-tests`: **89 tests passed**, including bundled entry acceptance of both names and rejection of US alone. Signed app build succeeded; `git diff --check` passed. Next action: reopen Mal and confirm soccer passes for 축구 with progress intact. This correction and the prior parenthetical-hint changes remain uncommitted for review.

## English-answer fixes approved — 2026-09-21

User reports “Seems to work” after the soccer correction and authorizes proceeding with the pending commit. Recorded user-tested outcome separately from automated evidence: latest suite remains 89 passing tests and signed app build succeeded. No implementation changes since verification; commit-time diff check passed. This checkpoint includes optional parenthetical English hints and explicit football/soccer alternatives. Next action: continue study and collect any remaining malformed dictionary alternatives; broader content/IME verification gates remain open.

## Comma-separated English alternatives — 2026-09-21

Fixed generic English grading for colour (UK), color (US): each top-level comma/semicolon fragment yields its own optional-hint answer, so both colour and color pass. Full gloss still accepted; parenthetical/bracketed commas are not separators. Personal aliases and Korean grading remain literal. No bank edits or progress changes.

Verification: final `swift test --scratch-path /tmp/mal-speech-tests`: **90 tests passed**. Initial run exposed the previous deliberate no-comma-splitting assertion; updated it to the requested policy and reran successfully. Tests cover colour/color, combined comma/semicolon meanings, internal commas and literal aliases. Signed app build succeeded; `git diff --check` passed.

Next action: reopen Mal and retry color for 색. Native acceptance pending; changes uncommitted for review. Prose commas can now admit shorter fragments; continue reporting ambiguous content for cleanup.

User acceptance follow-up: user reports “That worked” for the comma-separated colour/color fix. Recorded separately from the 90 passing automated tests. Changes remain uncommitted pending commit authorization. Next action: continue study and collect any remaining English-answer parsing defects.

Commit authorization: user explicitly requested committing the tested comma-separated answer fix. Latest verification remains 90 passing tests and successful signed app build, followed by positive user acceptance. No implementation changes since verification; commit-time diff check passed. Next action: continue study and report remaining content or grading issues.

## Direct Count as correct button — 2026-09-22

Replaced grading dropdown with Count as correct, always calling the existing correct-and-remember operation. Removed one-time UI override and mutable saveAlias toggle; action itself checks existing alias eligibility. English answers retain availability in all form categories. Focused Korean conjugations retain their prior unlabelled-alias restriction. No storage or grading rule changes.

Verification: signed app build succeeded; `git diff --check` passed. UI/action wiring change only; unit suite not rerun (latest full suite: 90 passed). Next manual acceptance: reopen Mal, submit an English answer judged wrong, click Count as correct, and verify corrected history plus future acceptance after restart. Changes remain uncommitted for review.
