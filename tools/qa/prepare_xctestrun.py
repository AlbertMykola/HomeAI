#!/usr/bin/env python3
"""Prepare a relocatable Xcode-generated test manifest for the UIKit QA catalog."""
import argparse
import pathlib
import plistlib


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=pathlib.Path, required=True)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    parser.add_argument('--languages', default='cs,da,de,en,es,fr,it,ja,ko,nb,nl,pl,pt-BR,ru,uk')
    parser.add_argument('--screens')
    parser.add_argument('--snapshots', action='store_true')
    parser.add_argument('--appearances', default='light')
    parser.add_argument('--snapshot-languages', help='Capture selected languages; layout checks still cover all requested languages')
    parser.add_argument('--strict-labels', action='store_true')
    parser.add_argument('--skip-generation-copy', action='store_true')
    parser.add_argument('--used-free', type=int, choices=[0, 1, 2], help='Explicit allowance state for focused layout checks')
    parser.add_argument('--scroll-content', action='store_true', help='Inspect static vertical content at overlapping scroll positions')
    args = parser.parse_args()
    root = args.source.resolve().parent
    data = plistlib.loads(args.source.read_bytes())
    updated = []
    def visit(value):
        if isinstance(value, str):
            return value.replace('__TESTROOT__', str(root))
        if isinstance(value, list):
            return [visit(item) for item in value]
        if isinstance(value, dict):
            if value.get('BlueprintName') in ['HomeAITests', 'HomeAIUITests']:
                env = value.setdefault('EnvironmentVariables', {})
                env['REHOMELY_FULL_QA'] = '1'
                if value['BlueprintName'] == 'HomeAITests':
                    env['REHOMELY_QA_LANGUAGES'] = args.languages
                    env['REHOMELY_QA_SNAPSHOTS'] = '1' if args.snapshots else '0'
                    env['REHOMELY_QA_APPEARANCES'] = args.appearances
                    env['REHOMELY_QA_STRICT_LABELS'] = '1' if args.strict_labels else '0'
                    env['REHOMELY_QA_SKIP_GENERATION_COPY'] = '1' if args.skip_generation_copy else '0'
                    env['REHOMELY_QA_SCROLL_CONTENT'] = '1' if args.scroll_content else '0'
                    if args.used_free is not None:
                        env['REHOMELY_QA_USED_FREE'] = str(args.used_free)
                    else:
                        env.pop('REHOMELY_QA_USED_FREE', None)
                    if args.snapshot_languages:
                        env['REHOMELY_QA_SNAPSHOT_LANGUAGES'] = args.snapshot_languages
                    else:
                        env.pop('REHOMELY_QA_SNAPSHOT_LANGUAGES', None)
                    if args.screens:
                        env['REHOMELY_QA_SCREENS'] = args.screens
                    else:
                        env.pop('REHOMELY_QA_SCREENS', None)
                updated.append(value['BlueprintName'])
            return {key: visit(item) for key, item in value.items()}
        return value
    data = visit(data)
    if 'HomeAITests' not in updated:
        parser.error('The source must include the HomeAITests target')
    args.output.write_bytes(plistlib.dumps(data))
    print('Prepared:', ', '.join(updated))


if __name__ == '__main__':
    main()
