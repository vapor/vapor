#!/usr/bin/env python3
"""Adapt the shared benchmark workflow to Vapor's isolated measurement modes."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


PACKAGE = Path(__file__).resolve().parent
METRICS = {
    "instructions": "instructions",
    "allocations": "mallocCountTotal",
    "cpu": "cpuTotal",
    "wall-clock": "wallClock",
}


def baseline_name(title, mode):
    # PR titles can contain path separators; keep every baseline in one directory.
    label = re.sub(r"[^A-Za-z0-9_.-]+", "_", title)[:80]
    digest = hashlib.sha256(title.encode()).hexdigest()[:8]
    return f"{label}-{digest}-{mode}"


def command(mode, *arguments, benchmark_filter=None):
    build = "allocations" if mode == "allocations" else "uninstrumented"
    result = [
        "swift", "package", "-c", "release", "--package-path", str(PACKAGE),
        "--scratch-path", str(PACKAGE / ".build" / build),
        "--disable-sandbox", "--allow-writing-to-package-directory",
    ]
    if mode == "allocations":
        result += ["--traits", "AllocationCounting"]
    result += ["benchmark", *arguments, "--no-progress"]
    # The plugin filters live fixtures by baseName but saved thresholds by tagged
    # name. Select at recording time; later operations use that complete baseline.
    if benchmark_filter and arguments[:2] == ("baseline", "update"):
        result += ["--filter", benchmark_filter]
    return result


def run(mode, *arguments, benchmark_filter=None, check=True):
    environment = dict(os.environ, BENCHMARK_MODE=mode,
                       NIO_SINGLETON_GROUP_LOOP_COUNT="2",
                       NIO_SINGLETON_BLOCKING_POOL_THREAD_COUNT="2")
    return subprocess.run(
        command(mode, *arguments, benchmark_filter=benchmark_filter),
        cwd=PACKAGE.parent, env=environment, check=check,
    ).returncode


def threshold_names(baseline):
    data = json.loads((PACKAGE / ".benchmarkBaselines" / "VaporBenchmarks"
                       / baseline / "results.json").read_text())
    # Swift encodes a dictionary with structured keys as alternating keys/values.
    results = data["results"]
    if not results or len(results) % 2:
        raise ValueError("The saved baseline contains no complete benchmark results.")
    names = [f"{key['target']}.{key['name']}.p90.json" for key in results[::2]]
    exported = [name.replace("/", "_").replace(" ", "_") for name in names]
    portable = [threshold_filename(name) for name in names]
    if len(set(exported)) != len(names) or len(set(portable)) != len(names):
        raise ValueError("Benchmark names collide after the plugin's filename normalization.")
    for name in names:
        if Path(name).is_absolute() or ".." in Path(name).parts:
            raise ValueError(f"Invalid threshold filename: {name}")
    return dict(zip(names, exported))


def threshold_filename(name):
    # Measurement tags include ':', which GitHub's artifact service rejects.
    return re.sub(r'[/\\:*?"<>|\s]', "_", name)


def validate_threshold(path, mode):
    values = json.loads(path.read_text())
    metric = METRICS[mode]
    if set(values) != {metric} or type(values[metric]) is not int or values[metric] < 0:
        raise ValueError(f"Expected exactly one nonnegative {metric} threshold in {path}")
    if mode == "instructions" and values[metric] == 0:
        raise ValueError(f"Instruction counters are unavailable or zero: {path}")
    return values[metric]


def thresholds(mode, operation, baseline, destination, benchmark_filter):
    names = threshold_names(baseline)
    # benchmark 1.36.2 exports sanitized filenames but reads original names.
    # Also validate every result: upstream accepts partially missing thresholds.
    with tempfile.TemporaryDirectory(prefix="vapor-thresholds-") as temporary:
        run(mode, "thresholds", "update", baseline, "--path", temporary,
            benchmark_filter=benchmark_filter)
        reference = Path(temporary) / "reference"
        zero_regressions = []
        for original, exported in names.items():
            source = Path(temporary) / exported
            current = validate_threshold(source, mode)
            target = destination / mode / threshold_filename(original)
            if operation == "update":
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
            else:
                previous = validate_threshold(target, mode)
                # Upstream defines percentage change from zero as zero. Do not
                # silently accept newly allocating or newly measurable work.
                if previous == 0 and current > 0:
                    zero_regressions.append(original)
                # The plugin reads original names, including slashes and spaces.
                readable = reference / original
                readable.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(target, readable)
        if operation == "update":
            return 0
        status = run(mode, "thresholds", "check", baseline, "--path", str(reference),
                     "--format", "markdown", benchmark_filter=benchmark_filter, check=False)
        for name in zero_regressions:
            print(f"Regression: {name} was zero and is now positive.", flush=True)
        return comparison_status([status, 2] if zero_regressions else [status])


def comparison_status(statuses):
    # Preserve the exit-code contract used by vapor/ci and Penny's report.
    for status in statuses:
        if status not in (0, 1, 2, 4):
            return status if status > 0 else 1
    if 1 in statuses or (2 in statuses and 4 in statuses):
        return 1
    return 2 if 2 in statuses else 4 if 4 in statuses else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("category", choices=["baseline", "thresholds"])
    parser.add_argument("operation", choices=["update", "read", "check"])
    parser.add_argument("baseline")
    parser.add_argument("--path", type=Path, default=PACKAGE / "Thresholds")
    parser.add_argument("--format", choices=["markdown"], default="markdown")
    parser.add_argument("--mode", action="append", choices=METRICS)
    parser.add_argument("--filter")
    args = parser.parse_args()
    if (args.category, args.operation) not in {
        ("baseline", "update"), ("baseline", "read"),
        ("thresholds", "update"), ("thresholds", "check"),
    }:
        parser.error("Supported operations: baseline update/read, thresholds update/check.")
    if os.environ.get("BENCHMARK_SMOKE") == "1":
        parser.error("Smoke measurements cannot be used for CI performance baselines.")

    statuses = []
    for mode in args.mode or METRICS:
        print(f"\n## {mode}\n", flush=True)
        baseline = baseline_name(args.baseline, mode)
        try:
            if args.category == "thresholds":
                status = thresholds(mode, args.operation, baseline, args.path.resolve(), args.filter)
            else:
                options = ["--format", args.format, "--grouping", "metric"] if args.operation == "read" else []
                status = run(mode, "baseline", args.operation, baseline, *options,
                             benchmark_filter=args.filter)
            statuses.append(status)
        except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
            print(f"\n{mode} failed: {error}\n", flush=True)
            if args.category != "thresholds" or args.operation != "check":
                return 1
            # Keep reporting the remaining modes, but never call incomplete data a pass.
            statuses.append(30)
    return comparison_status(statuses)


if __name__ == "__main__":
    sys.exit(main())
