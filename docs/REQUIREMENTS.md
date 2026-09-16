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
| LEARN-02 | Continuous rotation; default learning-pool target 10 per track controls mixing while reviews are ready. Always introduce unseen words when no review is ready, even above target. |
| LEARN-03 | Learning: immediate → 10 minutes → 1 day; three consecutive due successes graduate to 3-day review. |
| LEARN-04 | Review multiplier typed 1.5+accuracy, choice 1.2+0.5×accuracy; smoothed latest 20 accuracy; max 365 days. |
| LEARN-05 | Failure resets learning, or relearns at 10 minutes and 1 day; preserve lifetime history. |
| LEARN-06 | Due relearning, then overdue reviews; no automatic batch or daily pauses; no future reviews pulled forward. |
| LEARN-07 | Separate presentation and grade records; atomic grade+schedule; undo restores prior state. |
| STORE-01 | Content, aliases, events, settings and schedules separated; progress survives app/bank replacement. |
| STORE-02 | Standalone backups, transactional restore, pre-migration/pre-restore recovery backups. |
| ENG-01 | Pure testable rules module, injected time/randomness, unit and integration tests. |
| ENG-02 | Git and repository Markdown track requirements, decisions, milestones, defects, evidence and handoffs. |

Deferred: cloud sync, distribution/notarization, in-app vocabulary editor, AI/URL bank generation, romanized answers, sentence-cloze exercises.
