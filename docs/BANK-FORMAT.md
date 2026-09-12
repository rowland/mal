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

Each Korean form has required `text` and optional `speechLevel` (descriptive label), `honorific` (boolean), and `attributive` (boolean). The lemma is always accepted. A label does not generate or infer forms. The English list contains accepted answers, not a prose definition requiring interpretation. The first English answer is the displayed gloss. Cues appear on prompts in both directions and are not part of required answers.

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
