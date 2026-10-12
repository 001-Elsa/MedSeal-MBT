#!/usr/bin/env python3
"""Generate a public rule catalog from reviewed facts, never infer certification.

--import-sources reads locally saved official XHTML once. Ordinary generation
and --check are offline and require only the committed reviewed facts.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import xml.etree.ElementTree as ET
from moon_tokens import semantic_tokens

REPO = Path(__file__).resolve().parents[1]
FOLDER = REPO / 'resources/rules'
NS = {'h': 'http://www.w3.org/1999/xhtml'}
SOURCE_BASE = 'https://dicom.nema.org/medical/dicom/2025e/output/chtml/'
ACTION = {'identity': 'replace', 'instance-uid': 'remap', 'standard-uid': 'keep',
          'shift-da': 'shift', 'empty': 'empty', 'descriptive': 'empty',
          'remove': 'remove', 'sequence': 'recurse', 'keep': 'keep'}


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + '\n'


def import_sources(root):
    rows = {}
    source = root / 'part15__chapter_E.html'
    document = ET.fromstring(source.read_bytes())
    for row in document.findall('.//h:tr', NS):
        cells = [' '.join(''.join(c.itertext()).split()) for c in row]
        if len(cells) >= 5 and re.fullmatch(r'\([0-9A-F]{4},[0-9A-F]{4}\)', cells[1]):
            tag = cells[1].replace('(', '').replace(')', '').replace(',', '')
            rows[tag] = {'basic_action': cells[4],
                         'modified_dates_option': cells[11] if len(cells) > 11 else ''}
    if rows.get('00100010', {}).get('basic_action') != 'Z':
        raise ValueError('official confidentiality table not recognized')
    dictionary_source = root / 'part06__chapter_6.html'
    attributes = {}
    for row in ET.fromstring(dictionary_source.read_bytes()).findall('.//h:tr', NS):
        cells = [' '.join(''.join(c.itertext()).split()).replace('\u200b', '') for c in row]
        if len(cells) >= 5 and re.fullmatch(r'\([0-9A-F]{4},[0-9A-F]{4}\)', cells[0]):
            tag = cells[0].replace('(', '').replace(')', '').replace(',', '')
            attributes[tag] = {'vr': cells[3], 'vm': cells[4]}
    selected = json.loads((FOLDER / 'strict-v1.json').read_text(encoding='utf-8'))['attributes']
    for a in selected:
        if attributes.get(a['tag']) != {'vr': a['vr'], 'vm': a['vm']}:
            raise ValueError('official VR/VM differs from pinned subset: ' + a['tag'])
    facts = {'schema': 1, 'edition': '2025e', 'table': 'PS3.15 Table E.1-1',
             'source_url': SOURCE_BASE + 'part15/chapter_E.html#table_E.1-1',
             'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
             'source_documents': json.loads((root / 'sources.json').read_text(encoding='utf-8')),
             'attribute_actions': rows,
             'dictionary_source_sha256': hashlib.sha256(dictionary_source.read_bytes()).hexdigest(),
             'reviewed_dictionary_facts': {a['tag']: attributes[a['tag']] for a in selected},
             'notice': 'Short factual action codes, not copied narrative or a certification claim.'}
    (FOLDER / 'standard-facts-2025e.json').write_text(canonical(facts), encoding='utf-8', newline='\n')


def products():
    dictionary = json.loads((FOLDER / 'strict-v1.json').read_text(encoding='utf-8'))
    facts = json.loads((FOLDER / 'standard-facts-2025e.json').read_text(encoding='utf-8'))
    rules = []
    for attribute in dictionary['attributes']:
        tag, role = attribute['tag'], attribute['role']
        source = facts['attribute_actions'].get(tag)
        # A table action describes an option, not this project's full policy.
        references = [{'document': 'PS3.6', 'edition': '2025e', 'section': '6',
                       'table': '6-1', 'row': f'({tag[:4]},{tag[4:]})',
                       'url': SOURCE_BASE + 'part06/chapter_6.html#table_6-1',
                       'source_sha256': facts['dictionary_source_sha256'],
                       'purpose': 'attribute VR/VM; checked against official 2025e and pinned pydicom 3.0.1 data'}]
        if source:
            references.append({'document': 'PS3.15', 'edition': '2025e', 'section': 'E.1',
                               'table': 'E.1-1', 'row': references[0]['row'],
                               'url': facts['source_url'], 'purpose': 'confidentiality action options',
                               'source_sha256': facts['source_sha256'], **source})
        rules.append({'id': 'attr-' + tag, 'tag': tag, 'name': attribute['name'],
                      'vr': attribute['vr'], 'vm': attribute['vm'], 'role': role,
                      'action': ACTION[role], 'profiles': ['strict-v1'],
                      'context': 'top-level; nested reference context is separately restricted',
                      'condition': {'kind': 'known-attribute'}, 'iod_type': 'not assigned by attribute dictionary; requiredness is separately cataloged', 'references': references,
                      'policy_basis': 'MedSeal reviewed research policy; not an assertion that all Annex E options are implemented',
                      'support': 'implemented-attribute-classification-vr-vm',
                      'implementation': ['src/rulebook/attributes.mbt', 'src/conformance/profile.mbt', 'src/identity/transform.mbt'],
                      'positive_case': 'rule-' + tag + '-valid-field',
                      'negative_case': 'rule-' + tag + '-wrong-vr',
                      'test': 'src/conformance/attributes_test.mbt'})
    data = {'schema': 1, 'rulebook_version': '1.0.0', 'standard': 'DICOM 2025e',
            'dictionary_sha256': hashlib.sha256((FOLDER / 'strict-v1.json').read_bytes()).hexdigest(),
            'scope': 'Existing strict attribute classification and VR/VM, plus separately cataloged implementation contracts. Not complete IOD or Annex E.',
            'rules': rules + json.loads((FOLDER / 'contracts-v1.json').read_text(encoding='utf-8'))['rules']}
    raw = canonical(data)
    digest = hashlib.sha256(raw.encode()).hexdigest()
    lines = ['// Generated by tools/generate_rulebook.py; do not edit.', '///|',
             f'pub let digest : String = "{digest}"', '///|', 'pub fn lookup(tag : @model.Tag) -> Entry? {', '  match (tag.group, tag.element) {']
    for r in rules:
        lines += [f'    (0x{r["tag"][:4]}U, 0x{r["tag"][4:]}U) => Some({{ id: "{r["id"]}", tag, vr: "{r["vr"]}", vm: "{r["vm"]}", role: "{r["role"]}", action: "{r["action"]}", confidentiality_table: {str(len(r["references"]) > 1).lower()} }})']
    lines += ['    _ => None', '  }', '}', '']
    tests = ['// Generated from reviewed catalog. Runs the production field checker.', '///|',
             'test "every reviewed attribute accepts its declared VR and rejects another VR" {']
    for r in rules:
        allowed = r['vr'].split(' or ')
        valid = allowed[0]
        invalid = next(v for v in ('PN', 'US', 'SQ') if v not in allowed)
        t = f'@model.Tag::new(0x{r["tag"][:4]}U, 0x{r["tag"][4:]}U)'
        tests += [f'  // {r["positive_case"]}; {r["negative_case"]}',
                  f'  let t = {t}', f'  let value = @model.DataElement::new(t, @model.Vr::{valid}, 0U, @model.ElementValue::Empty, 0)',
                  '  @conformance.check_attribute(value)',
                  f'  let wrong = @model.DataElement::new(t, @model.Vr::{invalid}, 0U, @model.ElementValue::Empty, 0)',
                  '  let rejected = try { @conformance.check_attribute(wrong); false } catch { @model.MedSealError::RuleViolation(_, _, _, "vr") => true; _ => false }',
                  '  assert_true(rejected)',
                  f'  assert_eq(@rulebook.lookup(t).unwrap().action, "{r["action"]}")']
    tests += ['}', '']
    contracts = ['// Generated by tools/generate_rulebook.py; do not edit.', '///|',
                 'pub fn known_contract(id : String) -> Bool {', '  match id {']
    for rule in data['rules']:
        contracts.append('    ' + json.dumps(rule['id']) + ' => true')
    contracts += ['    _ => false', '  }', '}', '///|',
                  'pub fn contract_source(id : String) -> String {', '  match id {']
    for rule in data['rules']:
        source = '; '.join(r['document'] + ' ' + r.get('section', '') for r in rule['references'])
        contracts.append('    ' + json.dumps(rule['id']) + ' => ' + json.dumps(source))
    contracts += ['    _ => "MedSeal public error contract v1"', '  }', '}', '///|',
                  'pub fn contract_evidence(id : String) -> String {', '  match id {']
    for rule in data['rules']:
        contracts.append('    ' + json.dumps(rule['id']) + ' => ' + json.dumps(rule['negative_case']))
    contracts += ['    _ => "public-error-canary"', '  }', '}', '']
    return {FOLDER / 'rulebook-v1.json': raw, REPO / 'src/rulebook/attributes.mbt': '\n'.join(lines),
            REPO / 'src/conformance/attributes_test.mbt': '\n'.join(tests),
            REPO / 'src/rulebook/contracts.mbt': '\n'.join(contracts)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--import-sources', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.import_sources:
        import_sources(args.import_sources)
    for path, data in products().items():
        if args.check:
            # Whitespace alone is owned by moon fmt; tokens must still match.
            normalize = semantic_tokens
            if not path.exists() or (path.read_text(encoding='utf-8') != data if path.suffix == '.json' else normalize(path.read_text(encoding='utf-8')) != normalize(data)):
                raise ValueError('rulebook drift: ' + str(path.relative_to(REPO)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(data, encoding='utf-8', newline='\n')
    print('Rulebook generated/checked offline; no full-IOD certification claim.')


if __name__ == '__main__':
    main()
