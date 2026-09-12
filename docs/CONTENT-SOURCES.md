# Vocabulary provenance and review

## Sources

1. **National Institute of Korean Language**, Korean learner vocabulary list (May 2003). [Source page](https://www.korean.go.kr/front_eng/down/down_02V.do?etc_seq=70&pageIndex=1). The page expressly permits reuse under **KOGL Type 1**, requiring source attribution. It supplies 2002 frequency rank and A/B/C learner difficulty, not current school grades or English translations.
2. **English Wiktionary contributors**, Korean entries, via [Kaikki](https://kaikki.org/dictionary/Korean/index.html). Download: `https://kaikki.org/dictionary/Korean/kaikki.org-dictionary-Korean.jsonl`. Snapshot extracted 2026-09-09 from the 2026-09-02 dump using Wiktextract. Each entry's notes link to its Wiktionary page and contributor history is available there. [Wiktionary reuse terms](https://en.wiktionary.org/wiki/Wiktionary:Copyrights); derived vocabulary files are distributed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
3. Mal's original editorial starting slice: 49 vocabulary entries with explicitly reviewed common forms, still awaiting independent linguistic verification.

The vocabulary data license applies to the vocabulary and derived source manifest, not automatically to the application source code. Changes from sources: vocabulary selection, tier assignment, gloss splitting, restricted present-form extraction, original example edits, and YAML restructuring. Attribution and license notices travel with the bundled banks and app resources.

## Reproducibility

`scripts/assemble-banks.py` takes a local CP949 NIKL text file and a local Kaikki JSONL file. No runtime network service or AI provider is used. `content-manifest.json` records SHA-256 input digests, NIKL source rows, source sense IDs, final stable IDs, and status. Do not rerun assembly over published banks: edit entries with their existing IDs and increment contentVersion.

## Review gate

All five banks contain 500 distinct Korean lemmas. The first 49 entries in Novice are editorially checked. The remaining 2,451 entries are **draft source matches**, not independently verified. Automatic source matching cannot safely resolve every homonym, equivalent synonym, or domain-specific gloss. Extracted honorific labels also require review because Wiktextract's tables do not consistently tag honorific status.

The release validator must fail until there are 500 verified entries per bank. Do not remove this gate to make a build appear complete.

For each entry, review:

- Korean lemma and part of speech agree with the selected lexical sense.
- English prompt is concise and unambiguous; add a sense cue where needed.
- Every listed answer is equivalent; include common synonyms and their valid forms.
- Present affirmative speech-level, honorific, and attributive forms are correct; no tense/negation leakage.
- Frequency/learner level and assigned tier make educational sense.
- Record source evidence and set verified only after independent review.

## Content limitations to resolve

- C-001: Complete independent verification for all entries.
- C-002: Audit automatically selected homonyms and English gloss splits.
- C-003: Audit extracted honorific labels and omitted attributive variants.
- C-004: Expand curated synonym equivalence, especially adjective pairs and honorific vocabulary.
- C-005: Review five-tier placement; NIKL A/B/C is only an initial aid, and the 2002 frequency data is dated.
