#!/usr/bin/env python3
"""Audit shipped strings, format arguments, duplicate keys and source references."""
import argparse
import collections
import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
KEY = re.compile(r'^\s*"((?:\\.|[^"\\])*)"\s*=', re.M)
ARG = re.compile(r'%(?:(\d+)\$)?[-+ #0]*\d*(?:\.\d+)?(?:hh|ll|[hlLzjt])?([@diuoxXfFeEgGcCsSp])')


def arguments(value):
    value = value.replace('%%', '')
    args = []
    for index, (position, kind) in enumerate(ARG.findall(value), 1):
        args.append((int(position) if position else index, kind))
    return sorted(args)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=pathlib.Path, required=True)
    opts = parser.parse_args()
    tables, duplicates = {}, {}
    for path in sorted((ROOT / 'HomeAI/Resources').glob('*.lproj/Localizable.strings')):
        lang = path.parent.name.removesuffix('.lproj')
        tables[lang] = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))
        duplicates[lang] = [k for k, count in collections.Counter(KEY.findall(path.read_text())).items() if count > 1]
    english = tables['en']
    result = {}
    for lang, table in tables.items():
        mismatches = {key: {'english': english[key], 'localized': table[key]}
                      for key in english.keys() & table.keys()
                      if arguments(english[key]) != arguments(table[key])}
        result[lang] = {'keys': len(table), 'missing': sorted(english.keys() - table.keys()),
                        'format_mismatches': mismatches, 'duplicates': duplicates[lang],
                        'identical': sorted(k for k in english.keys() & table.keys()
                                            if english[k] == table[k]) if lang != 'en' else []}
    referenced = set()
    for path in (ROOT / 'HomeAI').rglob('*.swift'):
        for raw in re.findall(r'"((?:\\.|[^"\\])*)"\.localized\b', path.read_text()):
            if '\\(' not in raw:
                try:
                    referenced.add(json.loads('"' + raw + '"'))
                except json.JSONDecodeError:
                    pass
    for path in (ROOT / 'HomeAI').rglob('*.xib'):
        import xml.etree.ElementTree as ET
        tree = ET.parse(path)
        if 'Redesign' in path.parts:
            referenced.update(a.get('label') for a in tree.iter('accessibility') if a.get('label'))
        for attr in tree.iter('userDefinedRuntimeAttribute'):
            if attr.get('keyPath') == 'locKey':
                if attr.get('value'):
                    referenced.add(attr.get('value'))
                for value in attr.iter('string'):
                    if value.text:
                        referenced.add(value.text)
    output = {'languages': result, 'source_keys_missing_from_english': sorted(referenced - english.keys())}
    opts.output.parent.mkdir(parents=True, exist_ok=True)
    opts.output.write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
    for lang, data in result.items():
        print(f"{lang:5} {data['keys']:4} keys; {len(data['missing'])} missing; "
              f"{len(data['format_mismatches'])} format mismatches; {len(data['duplicates'])} duplicates")
    print('Source keys missing from English:', len(output['source_keys_missing_from_english']))


if __name__ == '__main__':
    main()
