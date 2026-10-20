#!/usr/bin/env python3
"""Run the full app's hosted UIKit catalog on every configured simulator, two at a time."""
import argparse
import concurrent.futures
import ctypes
import fcntl
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import threading
import time

LOCK = threading.Lock()
CLONE_FILE = None
if sys.platform == 'darwin':
    CLONE_FILE = ctypes.CDLL('/usr/lib/libSystem.B.dylib', use_errno=True).clonefile
    CLONE_FILE.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
    CLONE_FILE.restype = ctypes.c_int


def copy_archive_file(source, destination):
    """Snapshot QA evidence with APFS copy-on-write, preserving the source bytes."""
    if CLONE_FILE is not None:
        temporary = str(destination) + '.qa-clone-' + str(threading.get_ident())
        try:
            if CLONE_FILE(os.fsencode(source), os.fsencode(temporary), 0) == 0:
                shutil.copystat(source, temporary)
                os.replace(temporary, destination)
                return str(destination)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    return shutil.copy2(source, destination)


def command(args, **kwargs):
    return subprocess.run(args, text=True, capture_output=True, **kwargs)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--devices', type=pathlib.Path, required=True)
    parser.add_argument('--products', type=pathlib.Path, required=True)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    parser.add_argument('--xctestrun', default='RehomelyMatrix.xctestrun')
    parser.add_argument('--only', nargs='*')
    parser.add_argument('--priority', nargs='*', default=[], help='Run these simulator IDs first, in the given order')
    parser.add_argument('--jobs', type=int, default=2)
    parser.add_argument('--max-booted', type=int, default=2, help='Shared simulator capacity; defaults to two')
    parser.add_argument('--timeout', type=int, default=900, help='Per-device test process deadline in seconds')
    parser.add_argument('--test', action='append', help='Xcode test identifier; repeat to select several suites or methods')
    opts = parser.parse_args()
    opts.output.mkdir(parents=True, exist_ok=True)
    devices = []
    for runtime, entries in json.loads(opts.devices.read_text())['devices'].items():
        for entry in entries:
            if entry['isAvailable'] and (not opts.only or entry['udid'] in opts.only):
                devices.append(dict(entry, runtime=runtime.split('SimRuntime.')[-1]))
    # Start with Duo and the smallest phone to surface compact-height defects early.
    priority = {udid: index for index, udid in enumerate(opts.priority)}
    devices.sort(key=lambda d: (priority.get(d['udid'], len(priority)),
                                0 if 'Duo' in d['name'] else 1 if 'SE' in d['name'] else 2, d['name']))
    if not devices:
        parser.error('No available simulator matches the selection')
    results = []

    def run(device):
        slug = re.sub(r'[^a-zA-Z0-9-]+', '-', device['name'] + '-' + device['runtime']) + '-' + device['udid'][:8]
        cached = opts.output / slug / 'result.json'
        if cached.exists():
            return json.loads(cached.read_text())
        # Separate matrix invocations must never install over a running test on
        # the same simulator. Hold this lease through archive and shutdown.
        with pathlib.Path('/private/tmp/rehomely-device-' + device['udid'] + '.lock').open('w') as device_lock:
            fcntl.flock(device_lock, fcntl.LOCK_EX)
            return run_device(device)

    def run_device(device):
        udid = device['udid']
        slug = re.sub(r'[^a-zA-Z0-9-]+', '-', device['name'] + '-' + device['runtime']) + '-' + udid[:8]
        folder = opts.output / slug
        folder.mkdir(exist_ok=True)
        start = time.monotonic()
        result = {'name': device['name'], 'runtime': device['runtime'], 'udid': udid, 'folder': str(folder)}
        existing = folder / 'result.json'
        if existing.exists():
            return json.loads(existing.read_text())
        with LOCK:
            print('START', device['name'], device['runtime'], flush=True)
        # Cooperate with a separate UI/motion run and other matrix workers on a 16 GB host.
        def booted_devices():
            state = json.loads(command(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']).stdout)
            return [d['udid'] for group in state['devices'].values() for d in group if d['state'] in ['Booted', 'Booting']]

        # A device that was already booted needs no capacity reservation. Waiting
        # newcomers retain the admission lock so later workers cannot starve them.
        if udid not in booted_devices():
            with pathlib.Path('/private/tmp/rehomely-simulator-boot.lock').open('w') as boot_lock:
                fcntl.flock(boot_lock, fcntl.LOCK_EX)
                while True:
                    booted = booted_devices()
                    if udid in booted or len(booted) < max(1, opts.max_booted):
                        command(['xcrun', 'simctl', 'boot', udid])
                        break
                    time.sleep(2)
        boot = command(['xcrun', 'simctl', 'bootstatus', udid, '-b'], timeout=180)
        if boot.returncode:
            result.update(status='boot-failed', error=boot.stderr[-2000:])
        else:
            args = ['xcodebuild', '-xctestrun', str(opts.products / opts.xctestrun),
                    '-destination', 'platform=iOS Simulator,id=' + udid,
                    '-parallel-testing-enabled', 'NO', '-collect-test-diagnostics', 'never',
                    '-resultBundlePath', str(folder / 'matrix.xcresult'), 'test-without-building']
            args[1:1] = ['-only-testing:' + test for test in (opts.test or ['HomeAITests/FullAppSnapshotTests'])]
            try:
                with (folder / 'test.log').open('w') as log:
                    code = subprocess.run(args, stdout=log, stderr=subprocess.STDOUT, timeout=opts.timeout).returncode
                result.update(status='passed' if code == 0 else 'failed', exit_code=code)
            except subprocess.TimeoutExpired:
                command(['xcrun', 'simctl', 'terminate', udid, 'com.albert.apps.design.ai'])
                result.update(status='timeout')
            container = command(['xcrun', 'simctl', 'get_app_container', udid, 'com.albert.apps.design.ai', 'data'])
            source = pathlib.Path(container.stdout.strip()) / 'Library/Application Support/FullAppQA'
            if container.returncode == 0 and source.exists():
                shutil.copytree(source, folder / 'data', dirs_exist_ok=True, copy_function=copy_archive_file)
                report = folder / 'data/layout-report.json'
                if report.exists() and (not opts.test or any('FullAppSnapshotTests' in test for test in opts.test)):
                    data = json.loads(report.read_text())
                    result.update(combinations=len(data['visited']), issues=len(data['issues']), size=data['size'])
        result['seconds'] = round(time.monotonic() - start, 1)
        existing.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        command(['xcrun', 'simctl', 'shutdown', udid])
        with LOCK:
            print('FINISH', json.dumps(result, ensure_ascii=False), flush=True)
        return result

    with concurrent.futures.ThreadPoolExecutor(max_workers=opts.jobs) as executor:
        futures = {executor.submit(run, device): device for device in devices}
        for future in concurrent.futures.as_completed(futures):
            try:
                results.append(future.result())
            except Exception as error:
                device = futures[future]
                results.append({'name': device['name'], 'udid': device['udid'], 'status': 'runner-error', 'error': str(error)})
            (opts.output / 'summary.json').write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n')
    return 0 if len(results) == len(devices) and all(result['status'] == 'passed' for result in results) else 1


if __name__ == '__main__':
    sys.exit(main())
