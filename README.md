# Mal · 말

A native, offline Korean flash-card app for macOS 26. SwiftUI interface, pure Swift learning rules, SQLite progress, YAML vocabulary banks.

## Build and run

Requires Xcode 26 and Swift 6.2 or newer. Open `Package.swift` in Xcode, select the Mal executable, and Run. Or:

```sh
swift test
./scripts/build-app.sh
open build/Mal.app
```

The first build downloads the pinned Yams 6.2.2 dependency. The app itself requires no network connection. The `.app` is ad-hoc signed for personal use; it is not notarized.

## Study

Select banks and parts of speech in the sidebar. Choose either translation direction and multiple choice or write-in. Multiple choice defaults to five choices; press 1–9 or 0 for the tenth choice. New cards first show the Korean form and English meanings; Continue/Return begins the quiz without recording a grade. Return submits typed answers. Correct answers advance immediately; wrong answers show the correct answer and pause for Return. Grading corrections are available in the Grading options menu. ⌘Z undoes the latest grade. ⌘P pronounces the Korean word. ⌘L opens the searchable bank browser.

The practice-form selector defaults to **Everyday polite**. Choose casual, formal polite, plain statement, noun-modifying, or subject-honorific practice. Conjugated forms appear in Korean prompts, choices, corrections and pronunciation. Focused write-in requires the selected form; **Dictionary / any answer** keeps the original vocabulary behavior. Each form category has independent progress. Ordinary nouns and adverbs retain their existing vocabulary track. Missing forms are counted and skipped. The bank browser's Listed forms section shows the available labeled variants.

Use Mal → Settings (⌘,) for choice count and learning-pool target. Recognition and write-in progress are independent. Newly introduced write-in cards prioritize recognized words. A new word gets an early recall after three intervening answers, before more new vocabulary. Successful short recall is followed by ten-minute and one-day checks, then expanding review intervals. When nothing is ready, unseen words continue automatically, even above the pool target. There are no automatic session pauses.

Progress lives in `~/Library/Application Support/Mal/Mal.sqlite`, independently of the app bundle. Use File → Back Up Progress before moving machines. Replacing the app preserves progress. This release backs up and upgrades the progress database to version 2; older builds cannot open the upgraded database. For isolated testing, launch the executable with `MAL_DATA_DIRECTORY=/tmp/mal-sandbox`.

## Content status

This is a development build, not a linguistically verified v1 release. Five 500-entry banks are assembled from attributed learner-frequency and dictionary sources. A curated starting slice is editorially checked; the remaining source matches are drafts. In particular, sense disambiguation, synonym coverage, and honorific labels need review before release. The library displays verification status; the release validator fails until all entries are verified.

See [project status](docs/STATUS.md), [requirements](docs/REQUIREMENTS.md), [decisions](docs/DECISIONS.md), [test plan](docs/TESTING.md), and [content sources](docs/CONTENT-SOURCES.md).

## Custom banks

Start with [Examples/colors.yaml](Examples/colors.yaml). Change the bank ID and entry IDs to your own namespace. Validate before importing:

```sh
swift run mal-bank Examples/colors.yaml
```

Import through File → Import Word Bank (⇧⌘I). Keep IDs stable and increase `contentVersion` for content changes. See [YAML format](docs/BANK-FORMAT.md).
