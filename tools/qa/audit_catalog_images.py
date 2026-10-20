#!/usr/bin/env python3
"""Read-only HEAD audit of literal catalog assets, mirroring local-first/folder fallback."""
import argparse
import concurrent.futures
import json
import pathlib
import re
import subprocess
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parents[2] / 'HomeAI'
BASE = 'https://dmgdmiyovhknsgylocge.supabase.co/storage/v1/object/public/Images/'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=pathlib.Path, required=True)
    args = parser.parse_args()
    paths = set()
    def visit(value):
        if isinstance(value, dict):
            for key, item in value.items():
                if key == 'image' and isinstance(item, str):
                    paths.add(item)
                else:
                    visit(item)
        elif isinstance(value, list):
            for item in value:
                visit(item)
    visit(json.loads((ROOT / 'Resources/InspirationJson.json').read_text()))
    for source in (ROOT / 'Entities/Enums').glob('*.swift'):
        for path in re.findall(r'"([^"\n]+\.(?:webp|png|jpg|jpeg))"', source.read_text()):
            if '\\(' not in path:
                paths.add(path)
    bundled = {p.stem for p in (ROOT / 'Assets.xcassets').rglob('*.imageset')}
    results = []
    remote = []
    for path in sorted(paths):
        if pathlib.Path(path).stem in bundled:
            results.append({'path': path, 'source': 'bundle', 'ok': True})
        else:
            remote.append(path)
    def head(path):
        url = BASE + urllib.parse.quote(path, safe='/')
        result = subprocess.run(['curl', '--head', '--location', '--silent', '--show-error', '--max-time', '15',
                                 '--output', '/dev/null', '--write-out', '%{http_code} %{content_type}', '--url', url],
                                text=True, capture_output=True)
        status, _, kind = result.stdout.partition(' ')
        return result.returncode == 0 and status == '200' and kind.startswith('image/'), status, kind
    def check(path):
        ok, status, kind = head(path)
        record = {'path': path, 'source': 'remote', 'status': status, 'content_type': kind, 'ok': ok}
        if not ok and '/' in path:
            ok, status, kind = head(pathlib.Path(path).name)
            record.update(fallback_ok=ok, fallback_status=status, fallback_content_type=kind, ok=ok)
        return record
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        results += list(executor.map(check, remote))
    report = {'total': len(results), 'bundled': len(results) - len(remote), 'remote': len(remote),
              'failed': sum(not r['ok'] for r in results), 'results': sorted(results, key=lambda r: r['path'])}
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'results'}))


if __name__ == '__main__':
    main()
