# Working on Mal

Read `docs/STATUS.md`, `docs/REQUIREMENTS.md`, and `docs/DECISIONS.md` before making changes. The accepted product name is Mal (말).

- Keep learning/grading/queue rules in the pure `MalCore` module; inject time and randomness and cover behavior with unit tests.
- Preserve stable content IDs and user progress. Never reset a personal database to make a test pass. Use a temporary Store or `MAL_DATA_DIRECTORY` for app testing.
- Recognition and write-in are independent tracks for each direction. Distractors come from the full selected banks, not the learning pool.
- Do not label draft vocabulary verified based on schema validation or automated source matching. Preserve source evidence and increment contentVersion when editing a bank.
- Update STATUS.md with exact test results, open defects, and the next concrete action after each iteration. Record product tradeoffs in DECISIONS.md.
- Run `swift test` for rules/storage changes. Use `scripts/build-app.sh` for a launchable app. Manual IME acceptance is separate from pasted-Hangul and unit tests.
- Keep changes focused and tracked in Git. No external issue tracker is configured.
