#!/usr/bin/env python3
"""Save reproducible counter and HTTP measurements for the current checkout."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
PERF = ROOT / "Performance"
TARGETS = ["VaporBenchmarks", "RawHTTPServerBenchmarks", "HummingbirdBenchmarks"]
HTTP_ROUTES = ["status", "tiny", "small", "json", "large", "stream", "stream-chunked",
               "stream-coarse", "stream-fine", "upload", "upload-stream"]


def run(command, log, env):
    print("+ " + " ".join(map(str, command)), flush=True)
    with log.open("w") as output:
        subprocess.run(list(map(str, command)), cwd=ROOT, env=env,
                       stdout=output, stderr=subprocess.STDOUT, check=True)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("name", help="unique result name, e.g. main-before-routing")
    parser.add_argument("--targets", nargs="+", choices=TARGETS, default=TARGETS)
    parser.add_argument("--filter", default="^(e2e|network|drain-network)/.*")
    parser.add_argument("--frameworks", nargs="+", default=["vapor", "http-server", "vapor4", "hummingbird"])
    parser.add_argument("--duration", type=int, default=10)
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--server-threads", type=int, default=4)
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--counters-only", action="store_true")
    parser.add_argument("--wrk", type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", args.name):
        parser.error("name must contain only letters, digits, underscores, dots and hyphens")
    if min(args.duration, args.repeats, args.server_threads) < 1:
        parser.error("duration, repeats and server-threads must be positive")
    if len(args.targets) != len(set(args.targets)):
        parser.error("targets must be unique")
    if os.environ.get("BENCHMARK_SMOKE") == "1":
        parser.error("unset BENCHMARK_SMOKE before recording performance results")
    output = PERF / "Results" / args.name
    output.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ, NIO_SINGLETON_GROUP_LOOP_COUNT=str(args.server_threads),
               NIO_SINGLETON_BLOCKING_POOL_THREAD_COUNT=str(args.server_threads))
    command_output = lambda cmd: subprocess.check_output(cmd, cwd=ROOT, text=True).strip()
    metadata = dict(name=args.name, utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    commit=command_output(["git", "rev-parse", "HEAD"]),
                    status=command_output(["git", "status", "--short"]),
                    platform=platform.platform(), swift=command_output(["swift", "--version"]),
                    arguments={k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()},
                    counter_scope="network includes client and server; e2e includes copying sink; trie excludes construction")
    (output / "source.diff").write_bytes(subprocess.check_output(["git", "diff", "HEAD"], cwd=ROOT))
    (output / "revision.json").write_text(json.dumps(metadata, indent=2) + "\n")
    # Build everything before any measurements. The plugin also builds BenchmarkTool
    # and the platform's interposer libraries with the package's configured traits.
    if not args.skip_build:
        run(["swift", "package", "--package-path", "Benchmarks", "--disable-sandbox",
             "--allow-writing-to-package-directory", "benchmark", "list"], output / "build-counters.log", env)
        if not args.counters_only:
            for package in [PERF, PERF / "Comparisons"]:
                run(["swift", "build", "--package-path", package, "-c", "release"],
                    output / ("build-" + package.name + ".log"), env)
    binary_dir = ROOT / "Benchmarks/.build/release"
    tool = binary_dir / "BenchmarkTool"
    if not tool.is_file():
        raise RuntimeError("BenchmarkTool is missing; rerun without --skip-build")
    libraries = sorted([*binary_dir.glob("lib*Interposer*.dylib"), *binary_dir.glob("lib*Interposer*.so")])
    if sys.platform.startswith("linux"):
        malloc_libraries = [path for path in libraries if "Malloc" in path.name]
        if not malloc_libraries:
            raise RuntimeError("Malloc interposer missing; enable benchmark's default traits for allocation measurements")
        env["LD_PRELOAD"] = ":".join([*[str(p) for p in libraries], *([env["LD_PRELOAD"]] if env.get("LD_PRELOAD") else [])])
    metadata["binary_sha256"] = {p.name: digest(p) for p in [tool, *libraries, *[binary_dir / name for name in args.targets]]}
    metadata["source_sha256"] = {str(p.relative_to(ROOT)): digest(p)
                                 for directory in ["Benchmarks", "Sources"]
                                 for p in (ROOT / directory).rglob("*.swift") if ".build" not in p.parts}
    metadata["workspace_states"] = {}
    for package, name in [(ROOT, "vapor"), (ROOT / "Benchmarks", "benchmarks"), (PERF, "performance"), (PERF / "Comparisons", "comparisons")]:
        if (package / "Package.resolved").exists():
            shutil.copyfile(package / "Package.resolved", output / f"dependencies-{name}.json")
        state = package / ".build/workspace-state.json"
        if state.exists():
            metadata["workspace_states"][name] = json.loads(state.read_text())["object"]["dependencies"]
    (output / "revision.json").write_text(json.dumps(metadata, indent=2) + "\n")
    for target in args.targets:
        target_output = output / target
        target_output.mkdir()
        common = [tool, "--command", "baseline", "--baseline-storage-path", output,
                  "--grouping", "benchmark", "--targets", target, "--baseline", args.name]
        run(common + ["--baseline-operation", "update", "--format", "text",
                      "--benchmark-executable-paths", binary_dir / target, "--filter", args.filter,
                      "--no-progress", "--scale", "--metrics", "instructions", "--metrics", "mallocCountTotal",
                      "--metrics", "wallClock", "--metrics", "throughput"], target_output / "counters.txt", env)
        run(common + ["--baseline-operation", "read", "--format", "jmh", "--path", target_output],
            target_output / "export.log", env)
        exports = list(target_output.glob("*.jmh.json"))
        if not exports or not all(json.loads(path.read_text()) for path in exports):
            raise RuntimeError(f"No counter results for {target}; check --filter and --targets")
        availability = {}
        for export in exports:
            for row in json.loads(export.read_text()):
                metrics = row.get("secondaryMetrics", {})
                availability[row["benchmark"]] = {
                    "instructions_available": metrics.get("Instructions", {}).get("score", 0) > 0,
                    "allocations_available": "Malloc (total)" in metrics,
                }
        (target_output / "metric-availability.json").write_text(json.dumps(availability, indent=2) + "\n")
        if any(not all(value.values()) for value in availability.values()):
            print(f"WARNING: {target} has unavailable counters; see metric-availability.json", flush=True)
    if not args.counters_only:
        run([sys.executable, PERF / "compare.py", *HTTP_ROUTES,
             "--frameworks", *args.frameworks, "--skip-build", "--duration", args.duration,
             "--warmup", "3", "--repeats", args.repeats, "--server-threads", args.server_threads,
             "--interleave-routes", "--record-cpu", "--output", output / "http",
             *(["--wrk", args.wrk] if args.wrk else [])], output / "http.txt", env)
    print(f"Completed {output}", flush=True)


if __name__ == "__main__":
    main()
