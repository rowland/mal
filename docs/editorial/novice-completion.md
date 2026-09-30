# Novice English-gloss pass completed — 2026-09-30

**All 500 entries have received the English-gloss/sense editorial pass. Full linguistic release verification is not complete.** Reviewer: assistant. The bank remains 500 active entries, contentVersion 25.

This continuation completed the remaining 425 entries in 17 checkpoints of 25 (batches 004–020): **147 revised, 278 retained**. Fourteen of the revisions replace the selected sense and therefore use new IDs. Earlier batches account for the other 75 reviewed entries, including the separate professor replacement.

## Main improvements

- Shorter prompts and explicit English alternatives instead of definition prose.
- Everyday US/UK variants such as mom/mum, flavor/flavour, airplane/aeroplane.
- Kinship prompts retain speaker-gender cues; counter notes retain the relevant number system.
- Removed fragments such as especially the beverage from accepted answers.
- Revised verbs retain explicit infinitive answers (for example, take a photo / to take a photo).

## Sense replacements in this continuation

| Korean | Previous selected meaning | New preferred meaning |
|---|---|---|
| 좀 | little while | a little |
| 바로 | truly | right away |
| 시장 | hunger | market |
| 타다 | burn | ride |
| 분 | unit of length equivalent to about 0.3 cm | minute |
| 혼자 | solitude | alone |
| 제일 | number one | most |
| 해 | sunlight | sun |
| 찍다 | chop | take a photo |
| 피우다 | cause to bloom | smoke |
| 별 | star (shape); a star symbol | star |
| 보통 | averageness | usually |
| 미안하다 | be ashamed of oneself | sorry |
| 남쪽 | South Korea in relation to North Korea | south |

New meanings were checked against the references recorded in the corresponding JSON row. These are editorial choices for usefulness, not claims of measured sense frequency. Original source glosses and ID mappings remain in the ledger. Other glossary cleanups are editorial judgments based on existing source-derived content and are not claimed as newly independently verified.

## Progress preservation

The 14 old IDs are retired on normal bank import. Their state, answer history and personal aliases remain in the database; the replacement senses start unseen. Unchanged IDs retain progress. No personal database was read or reset. Automatic aliases are not copied to replacement meanings. The app will introduce those senses as new cards. The previous professor replacement behaves the same way.

## Verification results

- 94 Swift tests passed, including every new sense retirement, retained old history/aliases/state, absent new mastery/aliases, unchanged-card state, idempotent import, and positive/negative grading examples.
- The first run found three migration-ledger arrays missing infinitive aliases; corrected the ledger and reran successfully.
- All five 500-entry banks passed schema validation. Other banks were not edited.
- Editorial ledger audit: 500 positions covered exactly once; all current IDs and answer arrays match their ledger rows.
- Signed app build and diff whitespace check passed.
- Native study behavior after this content update has not been manually exercised.

## Remaining verification work

Novice status remains **8 verified, 41 checked, 451 draft**. A gloss review alone does not certify every Korean conjugation, honorific label or imported frequency/sense association. Those labels were deliberately not bulk-promoted.

The 17 pending checks from batch 003 remain recorded there: complete predicate/synonym forms, failed lookups for 하얗다/좋다, a conflicting secondary conjugation table, and numeral form/metadata checks. This continuation inspected selected predicate records but did not establish enough new reference evidence to close those issues. The other draft entries also need complete-entry source review before a release-ready claim. Historical NIKL rank is provenance, not a guarantee that the initial automatic sense match was correct.

한번 was investigated and retained with its attested someday meaning; its note distinguishes the spaced 한 번 (one time). Do not normalize those spellings indiscriminately. Other useful senses of polysemous words can be added in a later content expansion, with their own IDs; this pass does not claim exhaustive sense coverage.

## Handoff

English-gloss editing for Novice is complete. Next work is a separate full-entry verification pass, starting with the 17 explicit batch-003 gaps, then the remaining unchecked forms and metadata. Do not begin Technician without direction. No vocabulary certification is requested from the user. Commit only when requested. See batches 001–020 for detailed decisions.
