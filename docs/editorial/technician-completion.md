# Technician English-gloss pass complete

2026-10-01 — assistant editor. All 500 entries reviewed in twenty bounded batches. Content version 22. Across the complete pass: 250 wording/cue revisions, 14 sense replacements, and 236 retained entries. The final eight batches cover positions 301–500: 123 wording/cue revisions, ten replacements, 67 retained.

## Scope and evidence

This is an English-gloss/sense editorial pass, not release-level linguistic verification. All 500 entries remain draft. Original source notes and exact before/after decisions appear in technician-001.json through technician-020.json; corresponding Markdown files are readable comparisons. Reference URLs in the ledgers identify sources actually consulted for doubtful senses. Existing Korean forms were preserved; their presence is not evidence of correctness.

Fourteen changes of sense use new stable IDs: 켜다, 한자, 시, 휴지, 자신, 내용, 글, 애, 그대로, 줄, 하루, 고개, 어리다, 대표. See technician-sense-replacements.json. Other entries retain IDs. Old history and personal aliases stay attached to retired senses; mastery is not copied to replacement cards. No personal database was read or modified.

Sense choices are editorial judgments about useful vocabulary, not measured rankings of frequency. Replacing a selected sense does not mean the earlier sense was wrong. For example, 줄's energy-unit homonym was replaced by the string/rope sense; other valid meanings still exist. The pass does not attempt exhaustive polysemy coverage.

NIKL evidence was consulted for 자신, 글, 줄, 어리다 and 분위기. Wiktionary evidence supports the other recorded distinctions and usage notes. A direct NIKL lookup for 내용 failed to load and searches did not provide a usable exact entry; its sense distinction is supported by the consulted Wiktionary page only. Broader physical raising meanings for 일으키다 were deferred; the card keeps rouse. No failed lookup counts as verification.

## Automated verification

- 97 Swift tests passed, including optional English infinitives, synonym exclusion and temporary-store updates for all 14 replacements. Old state/history/aliases survive, replacement mastery is absent, and identical reimports are no-ops. The 줄 category correction is covered.
- Technician validator: 500 entries, 500 awaiting independent verification; valid YAML v1.
- Ledger audit: all 500 positions covered exactly once, active IDs and English arrays match, 14 retired IDs absent; final-batch cues/categories also match.
- Signed launchable build: build/Mal.app. Whitespace checks passed.
- Initial test run encountered a compiler-cache sandbox restriction; authorized retry ran. Its ten assertion failures were exact-answer-set expectations that omitted the newly accepted infinitive variants; updated expectations then passed.
- Native study, speech and IME acceptance were not performed. The running app was not relaunched.

## Focused manual study checks

Use a temporary data directory for disposable tests, or install the built update for normal study without resetting progress.

1. In Korean→English write-in, check 나타나다 with “appear” and “to appear”; both should pass. Wrong tense “appeared” should fail.
2. Check 관심: “interest” should pass; definition fragments such as “or inclination to” should fail. 젊다 should not accept the old standalone age-range fragments.
3. Switch directions: confirm numeral prompts distinguish native/Sino-Korean and that contextual cues make head movements, cords, and the person-representative sense clear.
4. Browse retired/replacement history via existing history tools: old attempts must remain, while new senses start unseen. Ordinary wording changes must preserve their previous progress.
5. Evaluate long alternatives at a small window size in both directions and multiple-choice/write-in modes. This is usability feedback, not linguistic certification.

## Remaining editorial work

Complete-entry verification is next, beginning with predicates whose normal usage depends on constructions: 대하다, 위하다, 의하다 and 관하다. Their existing standalone speech-level practice may be unsuitable. Check every accepted Korean form, speech-level/honorific/attributive label, part of speech, and sense linkage before promoting status.

Then check remaining draft entries, prioritizing irregular predicates and the new senses, against recorded reference evidence. Review homonym/cue behavior in Korean→English: optional hints cannot resolve every uncatalogued meaning. Keep separate senses distinct rather than adding all dictionary meanings indiscriminately.

Novice's 17 documented batch-003 evidence gaps and wider content/tier verification remain open. CONTENT-001/002/003 and native QA tasks are not closed by this pass. No commit or app relaunch was performed.
