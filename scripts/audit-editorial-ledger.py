#!/usr/bin/env python3
"""Read-only coverage/identity audit; does not certify linguistic correctness."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
bank = (root / 'Sources/MalApp/Resources/Banks/novice.yaml').read_text()
blocks = bank.split('  - id: ')[1:]
entries = {n: (json.loads(b.splitlines()[0]), json.loads(re.search(r'    english: (.+)', b)[1]))
           for n, b in enumerate(blocks, 1)}
reviewed = {}
for path in sorted((root / 'docs/editorial').glob('novice-[0-9][0-9][0-9].json')):
    ledger = json.loads(path.read_text())
    assert len(ledger['entries']) <= 25, path
    for row in ledger['entries']:
        position = row['position']
        assert position not in reviewed, (path, position, 'duplicate review position')
        reviewed[position] = row
        assert entries[position] == (row['id'], row['after']), (path, position, 'bank differs from ledger')
assert len(entries) == 500
assert set(reviewed) == set(entries), sorted(set(entries) - set(reviewed))
ids = {entry[0] for entry in entries.values()}
assert len(ids) == 500
for row in json.loads((root / 'docs/editorial/novice-sense-replacements.json').read_text())['replacements']:
    assert row['oldID'] not in ids and row['newID'] in ids, row
print('500/500 positions covered exactly once; all ledger IDs/answers match; 14 retired IDs absent.')
print('This is structural coverage, not linguistic verification.')

technician = (root / 'Sources/MalApp/Resources/Banks/technician.yaml').read_text()
technician_blocks = technician.split('  - id: ')[1:]
technician_entries = {n: (json.loads(b.splitlines()[0]), json.loads(re.search(r'    english: (.+)', b)[1]))
                      for n, b in enumerate(technician_blocks, 1)}
technician_reviewed = {}
for path in sorted((root / 'docs/editorial').glob('technician-[0-9][0-9][0-9].json')):
    ledger = json.loads(path.read_text())
    assert len(ledger['entries']) <= 25, path
    for row in ledger['entries']:
        position = row['position']
        assert position not in technician_reviewed, (path, position, 'duplicate review position')
        technician_reviewed[position] = row
        assert technician_entries[position] == (row['id'], row['after']), (path, position, 'bank differs from ledger')
assert len(technician_entries) == 500
assert set(technician_reviewed) == set(range(1, len(technician_reviewed) + 1)), 'Technician review must remain sequential'
assert len({entry[0] for entry in technician_entries.values()}) == 500
print(f'{len(technician_reviewed)}/500 Technician positions covered sequentially; ledger IDs/answers match.')
print('Technician coverage is editorial only; it does not certify Korean forms or release readiness.')

technician_ids = {entry[0] for entry in technician_entries.values()}
replacements = json.loads((root / 'docs/editorial/technician-sense-replacements.json').read_text())['replacements']
for row in replacements:
    assert row['oldID'] not in technician_ids and row['newID'] in technician_ids, row
for position, row in technician_reviewed.items():
    if 'partOfSpeechAfter' not in row:
        continue
    block = technician_blocks[position - 1]
    def field(name):
        match = re.search(r'^    ' + name + r': (.+)$', block, re.M)
        return json.loads(match[1]) if match else None
    assert field('partOfSpeech') == row['partOfSpeechAfter'], (position, 'category mismatch')
    assert field('promptCue') == row['promptCueAfter'], (position, 'cue mismatch')
print(f'{len(replacements)} Technician retired IDs absent; replacement IDs present; new-batch cues/categories match.')
