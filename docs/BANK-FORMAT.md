# YAML bank format v1

Use UTF-8 YAML, as demonstrated in `Examples/colors.yaml`. Maximum imported file size: 20 MB. The complete document validates before any database change.

Required bank fields:

| Field | Meaning |
|---|---|
| schemaVersion | Exactly `1` |
| id | Stable ASCII letters/digits/dot/underscore/hyphen identifier; `mal.` reserved |
| contentVersion | Positive integer; increase when content changes |
| title | Nonempty displayed bank name |
| provenance | Nonempty `source`, `license`; optional `notes` |
| entries | Nonempty list |

Required entry fields: `id` (starts with bank ID plus a dot), `lemma`, `partOfSpeech` (`noun`, `verb`, `adjective`, `adverb`, `other`), nonempty `english` string list, `koreanForms` list (may be empty), and `verification` (`draft`, `checked`, `verified`). Optional `promptCue` and `notes` are strings.

Each Korean form has required `text` and optional `speechLevel` (descriptive label), `honorific` (boolean), and `attributive` (boolean). The lemma and all listed forms are accepted in Dictionary / any answer practice. Focused Korean production accepts only forms labeled for the selected category. A label does not generate or infer forms. The English list contains accepted answers, not a prose definition requiring interpretation. The first English answer is the displayed gloss. Cues appear on English-to-Korean prompts; Korean-to-English cues are optional hints. Cues are not part of required answers.

The grader accepts only explicit equivalents plus personal aliases. Avoid mixing different senses into one entry. Use a cue for English homonyms and Korean polysemy. Curate equivalent Korean predicates including their accepted forms; runtime suffix guessing is intentionally absent.

`draft`: automated/unreviewed entry. `checked`: editorial review performed, independent review still pending. `verified`: sense, accepted forms and metadata checked against a recorded source. Format validation is not linguistic validation.

## Updates

Preserve bank and sense IDs. Reimporting identical decoded content is a no-op. Changed content requires a strictly higher contentVersion. Removed entries are inactive but retain learning history. Reintroducing an ID reactivates it. A different meaning requires a new ID. Built-in banks may only be updated by the bundled-content loader.

Personal aliases remain separate and survive content updates. A backup contains content, active/retired entries, aliases, history, schedules and settings.

## Validator

```sh
swift run mal-bank Examples/colors.yaml
swift run mal-bank --built-in Sources/MalApp/Resources/Banks/*.yaml
swift run mal-bank --built-in --release Sources/MalApp/Resources/Banks/*.yaml
```

`--release` requires exactly 500 entries per bank and all verified. It is expected to fail for the current development content.

## Form practice (bank format remains v1)

The existing `koreanForms` structure supports actual study presentations. No suffix inference or generated conjugation occurs at runtime. Use these exact labels for present affirmative forms:

| Practice category | speechLevel | honorific | attributive |
|---|---|---|---|
| Casual | `informal` | false/omitted | false/omitted |
| Everyday polite | `informal-polite` | false/omitted | false/omitted |
| Formal polite | `formal-polite` | false/omitted | false/omitted |
| Plain statement | `formal` | false/omitted | false/omitted |
| Noun-modifying | omitted | false/omitted | true |
| Polite + subject honorific | `informal-polite` | true | false/omitted |
| Formal + subject honorific | `formal-polite` | true | false/omitted |

`formal` is the source label for plain declarative forms, not polite formal speech. Subject honorifics and listener politeness are separate dimensions. Existing unrecognized labels remain loadable but do not create a focused practice category. A missing category is skipped, never filled by guessing or dictionary fallback. Nouns/adverbs normally retain their base form and existing vocabulary progress. Listed attributive counters/numbers can also be practiced.

Multiple explicitly listed variants in one category are all accepted; their presentation is randomized. Synonyms must include correctly labeled forms of their own. Legacy personal aliases have no form labels, so they cannot satisfy a focused Korean production prompt. A one-off grade override remains available, but saving an untyped alias is hidden for focused form cards.

## Progress format v2 (separate from YAML schemaVersion)

SQLite user_version is now 2. Card keys add optional `formStyle`, a stable category identifier independent of spelling. Existing keys omit it and keep their exact storage IDs. New predicate keys append `|form:<category>`; each category has its own two directions × two answer modes. Recognition only prioritizes write-in within the same category. Progress does not imply mastery of the other spellings within a category; they share that category's schedule.

Opening a version-1 database makes a `Mal.sqlite.pre-migration-v1-<UUID>` backup before the transactional version update. Existing bank content, keys, aliases and history remain in place. Version-1 and version-2 backups can be restored; the live database is always marked version 2 afterward. Older Mal builds reject version 2 rather than silently discarding form identity. To use an older build, use the pre-migration backup with that build, not the upgraded database.

For uncued Korean-to-English form prompts, other catalogued lemmas of the same part of speech that share the displayed form contribute valid English meanings. Those meanings also cannot be distractors. The presented sense/category alone receives progress.
