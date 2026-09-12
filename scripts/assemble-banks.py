#!/usr/bin/env python3
"""Assemble reproducible DRAFT banks from locally downloaded, attributed sources.
Never marks automatically matched senses verified. Existing assignments are frozen
in docs/content-manifest.json; changing assignments requires an explicit migration.
Usage: python3 scripts/assemble-banks.py NIKL.txt Korean.jsonl
"""
import collections, hashlib, json, pathlib, re, sys
root = pathlib.Path(__file__).resolve().parents[1]
nikl_path, dictionary_path = map(pathlib.Path, sys.argv[1:])
if (root/'docs/content-manifest.json').exists():
    raise SystemExit('Initial assembly is frozen. Edit published entries with stable IDs; do not regenerate banks.')
rows = []
for line in nikl_path.read_bytes().decode('cp949').splitlines()[2:]:
    fields = line.split('\t')
    if len(fields) != 5: continue
    rank, word, pos, explanation, level = fields
    if not rank.isdigit() or level not in 'ABC' or pos not in ['명','동','형','부','수','대','의','관']: continue
    lemma = re.sub(r'\d+$', '', word)
    rows.append(dict(rank=int(rank), sourceWord=word, lemma=lemma, pos=pos, explanation=explanation, level=level))
lookup = collections.defaultdict(list)
for line in dictionary_path.open():
    d = json.loads(line)
    if re.fullmatch('[가-힣]+',d.get('word','')) and d.get('pos') in ['noun','verb','adj','adv','num','pron','counter','det']:
        lookup[d['word']].append(d)

# Explicitly edited examples for the first runnable slice. These are checked,
# not independently verified; the source manifest retains dictionary evidence.
curated = {
 '집': ('noun',['house','home'],[]),
 '물': ('noun',['water'],[]), '사람': ('noun',['person','human'],[]),
 '학교': ('noun',['school'],[]), '책': ('noun',['book'],[]),
 '밥': ('noun',['cooked rice','rice'],[]), '친구': ('noun',['friend'],[]),
 '오늘': ('noun',['today'],[]), '내일': ('noun',['tomorrow'],[]),
 '어제': ('noun',['yesterday'],[]), '시간': ('noun',['time'],[]),
 '이름': ('noun',['name'],[]), '한국': ('noun',['Korea'],[]),
 '한국어': ('noun',['Korean language','Korean'],[]),
 '가다': ('verb',['go','to go'],['가','가요','갑니다','가세요','가십니다','가는']),
 '오다': ('verb',['come','to come'],['와','와요','옵니다','오세요','오십니다','오는']),
 '하다': ('verb',['do','to do'],['해','하여','해요','하여요','합니다','하세요','하셔요','하십니다','하는']),
 '먹다': ('verb',['eat','to eat'],['먹어','먹어요','먹습니다','먹으세요','먹으십니다','먹는']),
 '마시다': ('verb',['drink','to drink'],['마셔','마셔요','마십니다','마시세요','마시십니다','마시는']),
 '보다': ('verb',['see','to see'],['봐','보아','봐요','보아요','봅니다','보세요','보십니다','보는']),
 '읽다': ('verb',['read','to read'],['읽어','읽어요','읽습니다','읽으세요','읽으십니다','읽는']),
 '듣다': ('verb',['listen','hear','to listen','to hear'],['들어','들어요','듣습니다','들으세요','들으십니다','듣는']),
 '걷다': ('verb',['walk','to walk'],['걸어','걸어요','걷습니다','걸으세요','걸으십니다','걷는']),
 '입다': ('verb',['wear'],['입어','입어요','입습니다','입으세요','입으십니다','입는']),
 '쓰다': ('verb',['wear'],['써','써요','씁니다','쓰세요','쓰십니다','쓰는']),
 '빨갛다': ('adjective',['red','be red'],['빨간','빨개','빨개요','빨갛습니다','빨가세요','빨가십니다']),
 '하얗다': ('adjective',['white','be white'],['하얀','하얘','하얘요','하얗습니다','하야세요','하야십니다']),
 '파랗다': ('adjective',['blue','be blue'],['파란','파래','파래요','파랗습니다','파라세요','파라십니다']),
 '좋다': ('adjective',['good','be good'],['좋은','좋아','좋아요','좋습니다','좋으세요','좋으십니다']),
 '크다': ('adjective',['big','large','be big'],['큰','커','커요','큽니다','크세요','크십니다']),
 '작다': ('adjective',['small','be small'],['작은','작아','작아요','작습니다','작으세요','작으십니다']),
 '춥다': ('adjective',['cold','be cold'],['추운','추워','추워요','춥습니다','추우세요','추우십니다']),
 '덥다': ('adjective',['hot','be hot'],['더운','더워','더워요','덥습니다','더우세요','더우십니다']),
 '빠르다': ('adjective',['fast','quick','be fast'],['빠른','빨라','빨라요','빠릅니다','빠르세요','빠르십니다']),
 '예쁘다': ('adjective',['pretty','beautiful','be pretty'],['예쁜','예뻐','예뻐요','예쁩니다','예쁘세요','예쁘십니다']),
 '많다': ('adjective',['many','much','numerous'],['많은','많아','많아요','많습니다','많으세요','많으십니다']),
 '조금': ('adverb',['a little','a bit'],[]), '빨리': ('adverb',['quickly','fast'],[]),
 '천천히': ('adverb',['slowly'],[]), '자주': ('adverb',['often','frequently'],[]),
 '항상': ('adverb',['always'],[]), '아주': ('adverb',['very'],[]),
 '하나': ('other',['one'],['한']), '둘': ('other',['two'],['두']),
 '셋': ('other',['three'],['세']), '넷': ('other',['four'],['네']),
 '일': ('other',['one'],[]), '이': ('other',['two'],[]),
 '명': ('other',['counter for people'],[]), '개': ('other',['counter for items'],[]),
}
cues = {'입다':'clothes', '쓰다':'a hat', '춥다':'weather or feeling cold', '덥다':'weather or feeling hot', '하나':'native Korean', '둘':'native Korean', '셋':'native Korean', '넷':'native Korean', '일':'Sino-Korean number', '이':'Sino-Korean number'}
posmap={'명':'noun','동':'verb','형':'adj','부':'adv','수':'num','대':'pron','의':'counter','관':'det'}
malpos={'noun':'noun','verb':'verb','adj':'adjective','adv':'adverb','num':'other','pron':'other','counter':'other','det':'other'}
banned={'archaic','obsolete','dialectal','North-Korea','historical','form-of','alternative','slang','vulgar'}

def accepted_forms(d):
    forms=[]; seen=set(); table=0
    for f in d.get('forms',[]):
        tags=set(f.get('tags',[])); value=f.get('form','')
        if 'inflection-template' in tags: table+=1
        indicative = 'indicative' in tags and 'non-past' in tags
        attributive = 'determiner' in tags and ('present' in tags or ('non-past' in tags))
        if not (indicative or attributive) or not re.fullmatch('[가-힣]+',value) or value in seen: continue
        seen.add(value)
        form={'text':value,'honorific': table>1,'attributive':attributive}
        if indicative: form['speechLevel']=('formal' if 'formal' in tags else 'informal')+('-polite' if 'polite' in tags else '')
        forms.append(form)
    return forms

def candidate(row):
    options=lookup[row['lemma']]
    match=next((x for x in options if x['pos']==posmap[row['pos']]),None)
    if not match: return None
    senses=[s for s in match.get('senses',[]) if not banned.intersection(s.get('tags',[])) and not s.get('form_of') and not s.get('alt_of') and s.get('glosses')]
    senses=[s for s in senses if len(s['glosses'][-1])<=95 and not re.search(r'^(alternative|synonym|abbreviation|hanja|romanization|contraction|honorific|polite|the |a |an )',s['glosses'][-1],re.I)]
    if not senses: return None
    sense=senses[0]; gloss=sense['glosses'][-1]
    # Split only short comma/semicolon lists; preserve definitions with clauses.
    glosses=[gloss]
    pieces=re.split(r';\s*|,\s*',gloss)
    if len(pieces)>1 and all(len(p.split())<=4 for p in pieces) and '(' not in gloss: glosses=pieces
    english=[]
    for g in glosses:
        g=g.strip().rstrip('.')
        if g.startswith('to '): english.append(g[3:])
        english.append(g)
    english=list(dict.fromkeys(english))
    return dict(lemma=row['lemma'],partOfSpeech=malpos[match['pos']],english=english,koreanForms=accepted_forms(match),verification='draft',notes='Source sense: '+gloss), sense

selected=[]; seen=set()
for lemma,(part,english,forms) in curated.items():
    row=next((r for r in rows if r['lemma']==lemma),None)
    if not row: continue
    labels=[]
    for value in forms:
        f={'text':value}
        if value.endswith('십니다') or value.endswith('세요') or value.endswith('셔요'): f['honorific']=True
        if value.endswith('니다'): f['speechLevel']='formal-polite'
        elif value.endswith('요'): f['speechLevel']='informal-polite'
        elif value.endswith(('는','은','운','란','간','얀','큰','른','쁜')) or value in ['한','두','세','네']: f['attributive']=True
        else: f['speechLevel']='informal'
        labels.append(f)
    e=dict(lemma=lemma,partOfSpeech=part,english=english,koreanForms=labels,verification='checked')
    if lemma in cues: e['promptCue']=cues[lemma]
    selected.append((row,e,{'id':'editorial-'+lemma}));seen.add(lemma)
# Rank within NIKL learner levels. Reserve upper banks for B/C rather than
# taking only the first 2,500 high-frequency items.
levels={x:[] for x in 'ABC'}
for row in sorted(rows,key=lambda r:(r['level'],r['rank'])):
    if row['lemma'] in seen: continue
    value=candidate(row)
    if not value: continue
    e,sense=value; levels[row['level']].append((row,e,sense));seen.add(row['lemma'])
assignments=[]
for index,name in enumerate(['novice','technician','general','advanced','extra']):
    chunk=selected[:] if index==0 else []
    preferred='A' if index<2 else 'B' if index<4 else 'C'
    for level in [preferred]+[x for x in 'ABC' if x!=preferred]:
        while len(chunk)<500 and levels[level]: chunk.append(levels[level].pop(0))
    if len(chunk)!=500: raise SystemExit(f'Insufficient source matches for {name}: {len(chunk)}')
    entries=[]
    for row,e,sense in chunk:
        identity=hashlib.sha256((row['sourceWord']+'|'+e['partOfSpeech']).encode()).hexdigest()[:16]
        e['id']='mal.'+name+'.'+identity
        source='https://en.wiktionary.org/wiki/'+e['lemma']+'#Korean'
        e['notes']=(e.get('notes','')+'\nSource: '+source+' · NIKL level '+row['level']+', frequency rank '+str(row['rank'])).strip()
        entries.append(e)
        assignments.append({'id':e['id'],'lemma':e['lemma'],'nikl':row,'dictionarySense':sense.get('id'),'verification':e['verification']})
    bank={'schemaVersion':1,'id':'mal.'+name,'contentVersion':1,'title':name.title(),'provenance':{'source':'NIKL Korean learner vocabulary (2003); English Wiktionary contributors via Kaikki, 2026-09-02 dump','license':'NIKL: KOGL Type 1 (attribution). Wiktionary-derived bank content: CC BY-SA 4.0. See docs/CONTENT-SOURCES.md.','notes':'Draft source matching requires independent linguistic review. Tiers are editorial, not official school grades.'},'entries':entries}
    # JSON is a YAML 1.2 subset; emit readable YAML without a Python dependency.
    def scalar(v): return json.dumps(v,ensure_ascii=False)
    lines=[]
    for k in ['schemaVersion','id','contentVersion','title']: lines.append(f'{k}: {scalar(bank[k])}')
    lines.append('provenance:')
    for k,v in bank['provenance'].items(): lines.append(f'  {k}: {scalar(v)}')
    lines.append('entries:')
    for e in entries:
        lines.append('  - id: '+scalar(e['id']))
        for k,v in e.items():
            if k=='id':continue
            lines.append(f'    {k}: {scalar(v)}')
    (root/'Sources/MalApp/Resources/Banks'/f'{name}.yaml').write_text('\n'.join(lines)+'\n')
    print(name,len(entries),collections.Counter(e['partOfSpeech'] for e in entries))
manifest={'inputs':{str(p.name):hashlib.sha256(p.read_bytes()).hexdigest() for p in [nikl_path,dictionary_path]},'entries':assignments}
(root/'docs/content-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
