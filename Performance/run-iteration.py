#!/usr/bin/env python3
"""Record one already-committed optimization revision. Run from any directory."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
PERF = ROOT / 'Performance'


def run(command, log, env):
    print('+ ' + ' '.join(map(str, command)), flush=True)
    with log.open('w') as output:
        subprocess.run(list(map(str, command)), cwd=ROOT, env=env,
                       stdout=output, stderr=subprocess.STDOUT, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name', help='unique name, e.g. 00-baseline or 01-batch-buffered')
    parser.add_argument('--filter', default='^(e2e|network)/')
    parser.add_argument('--frameworks', nargs='+', default=['vapor', 'http-server'])
    parser.add_argument('--duration', type=int, default=3)
    parser.add_argument('--repeats', type=int, default=3)
    parser.add_argument('--skip-build', action='store_true')
    args = parser.parse_args()
    output = PERF / 'Results' / 'iterations' / args.name
    output.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ, NIO_SINGLETON_GROUP_LOOP_COUNT='4', NIO_SINGLETON_BLOCKING_POOL_THREAD_COUNT='4')
    command_output = lambda cmd: subprocess.check_output(cmd, cwd=ROOT, text=True).strip()
    metadata = dict(name=args.name, utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    commit=command_output(['git', 'rev-parse', 'HEAD']),
                    status=command_output(['git', 'status', '--short']),
                    arguments=vars(args), counter_scope='network includes client and server; e2e includes copying sink')
    server_path = env.get('VAPOR_HTTP_SERVER_PATH')
    if server_path:
        metadata['http_server_commit'] = command_output(['git', '-C', server_path, 'rev-parse', 'HEAD'])
        metadata['http_server_status'] = command_output(['git', '-C', server_path, 'status', '--short'])
    (output / 'revision.json').write_text(json.dumps(metadata, indent=2) + '\n')
    if not args.skip_build:
        run(['swift', 'build', '--package-path', 'Performance', '-c', 'release'], output / 'build.log', env)
    # The benchmark plugin builds before executing; it is finished before wrk starts.
    baseline = 'iteration-' + args.name
    command = ['swift', 'package', '--package-path', 'Benchmarks', '--allow-writing-to-package-directory',
               'benchmark', 'baseline', 'update', baseline, '--filter', args.filter, '--no-progress', '--scale',
               '--metric', 'instructions', '--metric', 'mallocCountTotal', '--metric', 'wallClock', '--metric', 'throughput']
    run(command, output / 'counters.txt', env)
    source = ROOT / 'Benchmarks' / '.benchmarkBaselines' / 'VaporBenchmarks' / baseline
    shutil.copytree(source, output / 'counter-baseline')
    run(['swift', 'package', '--package-path', 'Benchmarks', '--allow-writing-to-package-directory',
         'benchmark', 'baseline', 'read', baseline, '--format', 'jmh', '--path', str(output)],
        output / 'counter-export.log', env)
    for package, name in [(ROOT / 'Benchmarks', 'benchmarks'), (PERF, 'performance')]:
        shutil.copyfile(package / 'Package.resolved', output / f'dependencies-{name}.json')
    binary = ROOT / 'Benchmarks' / '.build' / 'release' / 'VaporBenchmarks'
    if binary.exists():
        metadata['counter_binary_sha256'] = hashlib.sha256(binary.read_bytes()).hexdigest()
        (output / 'revision.json').write_text(json.dumps(metadata, indent=2) + '\n')
    run([sys.executable, PERF / 'compare.py', 'status', 'tiny', 'json', 'large', 'stream',
         '--frameworks', *args.frameworks, '--skip-build', '--duration', args.duration,
         '--warmup', '1', '--repeats', args.repeats, '--output', output / 'http'], output / 'http.txt', env)
    print(f'Completed {output}', flush=True)


if __name__ == '__main__':
    main()
