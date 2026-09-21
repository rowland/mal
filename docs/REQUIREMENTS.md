# Mal requirements baseline

Accepted 2026-09-12. Working name Mal (말). This file preserves user decisions across iterations. Change requirements explicitly and record the reason in DECISIONS.md.

| ID | Requirement |
|---|---|
| UX-01 | Native macOS 26, personal offline use; no account, gamification, or daily caps. |
| UX-02 | Independent direction and answer-mode switches. Five choices by default, configurable 4/5/6/8/10; 30-point choice text and 28-point number labels; one full-width column, numbered top to bottom, with wrapping answers. |
| UX-03 | Distractors from all selected banks, not restricted to active rotation; prefer same part of speech, exclude valid alternatives. |
| UX-04 | All parts of speech by default; selectable filters preserve progress. |
| UX-05 | Immediate correct-answer advancement; incorrect answers emphasize the correct answer and Continue. Undo remains available; grade overrides/aliases are secondary menu actions. |
| UX-06 | Keyboard-only study; Return committing Hangul composition must not grade. |
| UX-09 | Before a track’s first quiz, introduce its Korean form and English meanings. Continue begins practice without grading the introduction. |
| UX-08 | Korean-to-English cues are opt-in hints; accept catalogued meanings for the same lemma/POS and exclude them from distractors. English-to-Korean cues remain visible. |
| UX-07 | On-demand installed Korean system voice plus persisted Auto checkbox: speak Korean-to-English presentations and English-to-Korean selected/submitted answers. Missing voice does not block study. |
| DATA-01 | Sense-based stable IDs, Korean lemma/POS, English aliases/cues, explicit labeled Korean forms, notes and verification status. |
| DATA-02 | Present and practice curated present affirmative speech levels/attributives. Focused write-in requires the chosen category; Dictionary / any answer accepts all curated forms. Reject unlisted tense/negative/typo variants. |
| DATA-03 | NFC and surrounding-whitespace normalization; English capitalization ignored. |
| DATA-04 | Five nonoverlapping 500-entry banks: Novice, Technician, General, Advanced, Extra; frequency and learner difficulty inform tiers. |
| DATA-05 | Provenance, redistribution terms, and linguistic review tracked. Draft/generated content is not release-ready. |
| DATA-06 | YAML v1, sample file, validator, atomic import, stable-ID updates, version checks, protected built-in namespace, retirement without history deletion. |
| LEARN-01 | Four independent tracks per sense and form category (direction × mode). Manual switching; recognition priority applies only within the same form category. |
| LEARN-02 | Continuous rotation without daily caps; at most four words awaiting a first repeat by default (configurable). Introduce only when no eligible cards are due, immediately when capacity permits. |
| LEARN-03 | Dual deadlines: after successive correct learning answers, 1 minute/3 answers, 5 minutes/8, 20 minutes/20, 6 hours/50, 1 day/100, then maintenance at 3 days/200. Either deadline suffices; advance only one step per success. |
| LEARN-04 | Indefinite maintenance: multiply both intervals by typed 1.5+accuracy or choice 1.2+0.5×accuracy; smoothed latest 20 accuracy. Cap time at 180 days and answers at max(1000, four times introduced cards in track). |
| LEARN-05 | Learning failure steps back two stages, retry 30 seconds/3 answers. Maintenance failure relearns at 30 seconds/3, 5 minutes/8, 20 minutes/20; three successes resume half prior intervals, minimum 1 day/50 answers. Preserve history. |
| LEARN-06 | Due relearning, then overdue maintenance, then learning; either clock establishes due status. At first-repeat capacity with nothing due, repeat the least recently answered early-learning card. Avoid previous sense when alternatives exist. |
| LEARN-07 | Presentation and grade records separate; atomically persist grades, schedules and track-local answer clocks. Undo restores prior state and counter. Status counts use only the selected track: in play = learning + in review; due is an overlapping subset. In review is ongoing maintenance, never exemption from review. |
| STORE-01 | Content, aliases, events, settings and schedules separated; progress survives app/bank replacement. |
| STORE-02 | Standalone backups, transactional restore, pre-migration/pre-restore recovery backups. |
| ENG-01 | Pure testable rules module, injected time/randomness, unit and integration tests. |
| ENG-02 | Git and repository Markdown track requirements, decisions, milestones, defects, evidence and handoffs. |

Deferred: cloud sync, distribution/notarization, in-app vocabulary editor, AI/URL bank generation, romanized answers, sentence-cloze exercises.

UX-10: During a quiz, offer I don’t know (⌘K). Reveal the word’s introduction, record unsuccessful recall, and continue to another card before a later retry. Show a distinct history label and support Undo. Keep Show hint independent.

UX-11: English→Korean write-in offers Korean speech input (⌘⇧R), with explicit microphone permission and visible listening/stopped states. Keep Speak Korean selected across cards/restarts until Write-in is selected. Listen automatically on quizzes; submit after endpoint detection and finalization of a nonempty utterance, or immediately on Return using the visible transcript. Escape stops recognition and edits this answer; speech resumes on the next quiz. Provide explicit model download/setup when needed, typing fallback, no cloud audio fallback, and no pronunciation scoring.

UX-12: Spoken practice waits without a thinking-time cutoff and finalizes after roughly 0.8 seconds of detected quiet following speech/transcription evidence; finalization remains bounded at 2 seconds. Correct spoken-mode submissions have no automatic answer replay; incorrect submissions retain correction audio when Auto is enabled. Return remains immediate.

UX-13: Automatically select an enabled Korean/English input source when the corresponding answer field gains focus, including speech correction editing. Preserve manual overrides during editing and restore the previous source on leaving. Never interrupt Hangul composition; if no matching enabled source exists, leave input unchanged.

DATA-07: English grading accepts top-level semicolon-separated meanings and optional leading infinitive “to ” for predicates; retain qualifiers and avoid arbitrary punctuation/comma splitting. English personal aliases can be saved in any Korean form category, with shared grading/distractor exclusion semantics.

UX-14: Spoken answers consider recognizer alternatives and limited plain/tense consonant tolerance. Every other nonempty unmatched speech transcript offers explicit recognition confirmation/retry before grading; no automatic speech failure based solely on unmatched text. Typed/edited answers retain exact grading, and speech accommodations never become vocabulary aliases.

DATA-08: Identical English meanings with matching part of speech and sense cue accept the corresponding curated Korean answers across installed banks, filtered to the selected form style. Adjective “be X” and “X” are equivalent wording. Show other valid focused Korean forms in introductions/corrections; keep progress per presented sense.

UX-15: Recognition confirmation offers all accepted Korean forms for the current sense/style, allowing the learner to confirm the synonym actually spoken. A suggested form must not hide other valid answers.

UX-16 (review trial, 2026-09-20): During spoken English→Korean practice, progressively intersect each live primary/alternative recognition hypothesis with the accepted Korean set for the prompt and selected form style. An exact whole-word/contiguous-phrase match submits immediately, including within an utterance containing extra words. No match continues listening until the existing silence endpoint or Return. Typed grading remains exact. Human review is required before committing this trial.

UX-17 (review trial): Speech accommodations use independently testable, named/versioned rules in MalCore, with evidence and explicit live/submission eligibility. Exact matches take precedence; automatic rule acceptance requires one distinct accepted answer across applicable rules/hypotheses. Do not chain rules or loosen typed grading. Initial rules: ㅐ/ㅔ and ㅒ/ㅖ vowel substitutions with otherwise identical syllables, plus the existing single plain/tense onset substitution.

UX-17 refinement: Both initial speech rules are live-enabled. Plain/tense tolerance permits one onset substitution, preserving vowels, final consonants, and all other syllables. Other consonant differences remain subject to confirmation.

UX-17 contextual trial: Permit one ㄹ/ㄷ final-consonant confusion immediately before an identical ㅇ-initial syllable with ㅏ/ㅓ, optionally with the supported plain/tense onset difference in that same preceding syllable. Preserve all other characters. Exclude ㅐ/ㅔ contexts pending evidence; retain exact precedence, ambiguity confirmation and strict typing.
