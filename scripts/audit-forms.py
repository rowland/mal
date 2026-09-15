#!/usr/bin/env python3
"""Report bundled predicate form coverage, not linguistic correctness.
Reads the repository's canonical one-line JSON form arrays inside YAML.
"""
import json
import pathlib
import re

root = pathlib.Path(__file__).resolve().parents[1]
styles = {'casual': ('informal', False), 'polite': ('informal-polite', False),
          'formalPolite': ('formal-polite', False), 'plain': ('formal', False),
          'honorificPolite': ('informal-polite', True), 'honorificFormal': ('formal-polite', True)}
report = {'status': 'Coverage only; unverified content remains unverified.', 'banks': {}}
for path in sorted((root / 'Sources/MalApp/Resources/Banks').glob('*.yaml')):
    entries = []
    for block in path.read_text().split('  - id: ')[1:]:
        def field(name):
            return json.loads(re.search(r'^    ' + name + r': (.+)', block, re.M)[1])
        if field('partOfSpeech') in ('verb', 'adjective'):
            entries.append((field('lemma'), field('koreanForms')))
    summary = {'predicates': len(entries), 'styles': {}}
    for style, (level, honorific) in styles.items():
        missing = [lemma for lemma, forms in entries if not any(f.get('speechLevel') == level and bool(f.get('honorific')) == honorific and not f.get('attributive') for f in forms)]
        summary['styles'][style] = {'available': len(entries) - len(missing), 'missing': missing}
    missing = [lemma for lemma, forms in entries if not any(f.get('attributive') and not f.get('honorific') for f in forms)]
    summary['styles']['attributive'] = {'available': len(entries) - len(missing), 'missing': missing}
    report['banks'][path.stem] = summary
print(json.dumps(report, ensure_ascii=False, indent=2))
