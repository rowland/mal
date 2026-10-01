# Bank-by-bank gloss revision

Finish Novice before starting another bank. Work in batches of at most 25 entries, saving a ledger and resume checkpoint after each batch. Batch 001 is a targeted sample; subsequent batches review the earliest entries not already recorded. Unchanged entries count as reviewed only after an actual editorial review and must be recorded explicitly.

For each entry, preserve its stable ID and sense. Prefer a brief natural English prompt, explicit valid answer alternatives, and separate notes or a cue for necessary context. Avoid adding broad synonyms merely because they sometimes translate the lemma. Prefer the commonly useful sense, not the first dictionary sense. Replace a poorly chosen sense with a new stable ID, record old/new IDs and evidence, and test retirement/history preservation. Do not carry mastery or personal aliases into the replacement sense.

Keep original source evidence and old/new arrays in a JSON ledger; provide a readable Markdown comparison. Record evidence actually consulted, lookup failures, unresolved questions, and review status. Personal aliases are suggestions only and are not automatically published. Existing data fields suffice; no format change is currently needed.

Increment the bank contentVersion for each delivered revision. Preserve attribution and CC BY-SA vocabulary licensing. Editorial revision, user acceptance, schema validation and independent linguistic verification are distinct statuses. Do not promote verification labels automatically.

Before delivery, validate the bank, check that any ID/form/cue/category changes are intentional and recorded, run the suite and build the app. Record exact results in STATUS.md. Review short prompts for changed synonym/distractor behavior in both directions. Leave each delivered batch uncommitted until a commit is requested. User feedback concerns usability and product direction; it is not a linguistic approval gate for continuing editorial work.

Current checkpoint: novice-completion.md. English-gloss/sense editorial coverage is 500/500 across batches 001–020; Novice version 26 after the focused 열심히 adjustment. Full-entry release verification remains separate: 8 verified, 41 checked, 451 draft. Technician gloss/sense review is complete at 500/500 in technician-001.md through technician-020.md; Technician version 22, with all 500 entries still draft. See technician-completion.md for scope, tests and the full-entry verification backlog. Novice full-entry source verification remains open, beginning with the 17 explicit batch-003 gaps.

## Editorial responsibility and status

The assistant is the vocabulary editor. It selects useful common senses, checks sources, decides accepted equivalents, investigates ambiguity, and owns evidence-based status changes. The user is a learner and product tester, not the vocabulary verifier. Do not ask the user to certify Korean accuracy or treat “looks good” as linguistic evidence. Ask only about product preferences or genuinely unresolved scope choices.

- **draft**: insufficient editorial review of the complete entry. A polished English gloss alone does not establish correct Korean forms or sense metadata.
- **checked**: the editor has reviewed the complete entry (sense, English alternatives, cues, Korean forms and labels, relevant metadata) and recorded the result. Independent source corroboration may remain pending.
- **verified**: the editor has checked the sense, accepted forms and metadata against recorded reference evidence, independently of generated content or automated matching. This is a documented source check, not a claim that a human Korean expert certified it. Record the reviewer as assistant, the sources/date, scope, and unresolved issues. Unresolved material issues prevent promotion.

The assistant may assign these statuses when the work supports them; user approval is neither necessary nor sufficient. Do not bulk-promote earlier gloss-only batches. Keep editorial progress separate from entry verification so a reviewed gloss can coexist with draft forms. Cross-check doubtful or conflicting meanings using another reputable reference; defer unsupported answers rather than guess. Increment contentVersion for status edits as for other content changes.

Continue in bounded batches with durable checkpoints, without requiring the user to approve each word. Commit authorization remains separate.
