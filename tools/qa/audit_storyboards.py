#!/usr/bin/env python3
"""Validate the editable storyboard scene graph, resources, and prototype wiring."""
import argparse
import json
import pathlib
import re
import xml.etree.ElementTree as ET


def audit(repo):
    folder = repo / 'HomeAI/Storyboards'
    documents = {}
    errors = []
    scenes = []
    prototypes = set()
    for path in sorted(folder.glob('*.storyboard')):
        root = ET.parse(path).getroot()
        documents[path.stem] = root
        ids = [node.get('id') for node in root.iter() if node.get('id')]
        if len(ids) != len(set(ids)):
            errors.append(f'{path.name}: duplicate Interface Builder ID')
        known = set(ids)
        for node in root.iter():
            for key in ('destination', 'firstItem', 'secondItem'):
                reference = node.get(key)
                if reference and reference not in known:
                    errors.append(f'{path.name}: unresolved {key}={reference}')
        resources = {n.get('name') for n in root.findall('resources/namedColor')}
        for node in root.iter('color'):
            if node.get('name') and node.get('name') not in resources:
                errors.append(f'{path.name}: missing named color resource {node.get("name")}')
        for scene in root.findall('scenes/scene'):
            controllers = [n for n in scene.find('objects') if n.get('sceneMemberID') == 'viewController']
            if len(controllers) != 1:
                errors.append(f'{path.name}: expected one controller per scene')
            for controller in controllers:
                scenes.append({'storyboard': path.stem, 'identifier': controller.get('storyboardIdentifier'),
                               'class': controller.get('customClass')})
        for node in root.findall('.//collectionView/cells/collectionViewCell') + root.findall('.//tableView/prototypes/tableViewCell'):
            if not node.get('reuseIdentifier'):
                errors.append(f'{path.name}: prototype has no reuse identifier')
            prototypes.add(node.get('customClass') or node.tag)
    source = (folder / 'AppStoryboard.swift').read_text()
    for cases, name in re.findall(r'case (.*?): name = "(.*?)"', source):
        for identifier in re.findall(r'"(.*?)"', cases):
            if not any(s['storyboard'] == name and s['identifier'] == identifier for s in scenes):
                errors.append(f'Factory scene missing: {name}/{identifier}')
    for identifier in ('OnboardingTools', 'OnboardingWords', 'DSToastView', 'EditorHotspotView', 'EditorSelectionView', 'SheetBackdropView'):
        if not any(s['identifier'] == identifier for s in scenes):
            errors.append(f'Missing editable scene: {identifier}')
    for path in (repo / 'HomeAI/Redesign').rglob('*.swift'):
        text = path.read_text()
        if re.search(r'UINib\(|loadNibNamed\(', text):
            errors.append(f'Current UI still loads a nib: {path.relative_to(repo)}')
    remaining = list((repo / 'HomeAI/Redesign').rglob('*.xib'))
    if remaining:
        errors.append('Superseded redesign XIBs remain in the app target')
    return {'storyboards': len(documents), 'scenes': scenes, 'prototypeClasses': sorted(prototypes), 'errors': errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=pathlib.Path)
    args = parser.parse_args()
    result = audit(pathlib.Path(__file__).resolve().parents[2])
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps({'storyboards': result['storyboards'], 'scenes': len(result['scenes']),
                      'prototypeClasses': len(result['prototypeClasses']), 'errors': result['errors']}, ensure_ascii=False))
    raise SystemExit(bool(result['errors']))


if __name__ == '__main__':
    main()
