#!/usr/bin/env python3
"""Preserve raw phase results and overlay later, targeted layout observations."""
import argparse
import json
import pathlib


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--phase', action='append', required=True, help='Ordered NAME=/absolute/results path')
    parser.add_argument('--output', type=pathlib.Path, required=True)
    parser.add_argument('--snapshot-languages', help='Only these locales are expected to have complete screenshot sets')
    args = parser.parse_args()
    snapshot_languages = set(args.snapshot_languages.split(',')) if args.snapshot_languages else None
    devices = {}
    phases = []
    for phase in args.phase:
        name, directory = phase.split('=', 1)
        entries = []
        for path in sorted(pathlib.Path(directory).glob('*/result.json')):
            raw = json.loads(path.read_text())
            report_path = path.parent / 'data/layout-report.json'
            entry = dict(raw, result_file=str(path), report_file=str(report_path))
            if report_path.exists():
                report = json.loads(report_path.read_text())
                visited = {(x['language'], x.get('appearance', 'light'), x['screen']) for x in report['visited']}
                entry['unique_combinations'] = len(visited)
                entry['languages'] = sorted({x[0] for x in visited})
                entry['appearances'] = sorted({x[1] for x in visited})
                entry['screens'] = sorted({x[2] for x in visited})
                screenshot_root = path.parent / 'data/screenshots'
                expected = [combo for combo in visited if snapshot_languages is None or combo[0] in snapshot_languages]
                entry['expected_screenshots'] = len(expected)
                entry['missing_screenshots'] = sum(
                    not (screenshot_root / lang / appearance / (screen + '.png')).exists()
                    and not (screenshot_root / lang / (screen + '.png')).exists()
                    for lang, appearance, screen in expected)
                device = devices.setdefault(raw['udid'], {'name': raw['name'], 'runtime': raw['runtime'], 'observations': {}})
                by_combo = {}
                for issue in report['issues']:
                    by_combo.setdefault((issue['language'], issue.get('appearance', 'light'), issue['screen']), []).append(issue)
                for combo in visited:
                    device['observations']['/'.join(combo)] = {'phase': name, 'issues': by_combo.get(combo, [])}
            entries.append(entry)
        phases.append({'name': name, 'device_count': len(entries),
                       'combinations': sum(x.get('unique_combinations', 0) for x in entries), 'devices': entries})
    latest = []
    for udid, device in sorted(devices.items(), key=lambda pair: (pair[1]['name'], pair[1]['runtime'])):
        issues = [issue for observation in device['observations'].values() for issue in observation['issues']]
        latest.append({'udid': udid, 'name': device['name'], 'runtime': device['runtime'],
                       'covered_combinations': len(device['observations']), 'latest_layout_issues': issues})
    result = {'note': 'Raw failures are preserved. Later targeted observations replace layout observations only; this is not a complete functional or Figma-equality verdict.',
              'phases': phases, 'latest_layout': latest,
              'latest_layout_issue_count': sum(len(d['latest_layout_issues']) for d in latest)}
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'phases': [{k: v for k, v in p.items() if k != 'devices'} for p in phases],
                      'latest_layout_issue_count': result['latest_layout_issue_count']}))


if __name__ == '__main__':
    main()
