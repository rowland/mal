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
