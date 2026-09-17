#!/usr/bin/env python3
"""Build and compare matching localhost HTTP/1.1 workloads. Python standard library only."""

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import socket
import statistics
import subprocess
import time
import urllib.request

ROOT = Path(__file__).resolve().parent
SERVERS = {
    "vapor": (ROOT, "PerformanceServer"),
    "vapor4": (ROOT / "Comparisons", "Vapor4PerformanceServer"),
    "hummingbird": (ROOT / "Comparisons", "HummingbirdPerformanceServer"),
    "http-server": (ROOT, "HTTPServerPerformanceServer"),
    "vapor-direct": (ROOT, "PerformanceServer"),
    "vapor-no-middleware": (ROOT, "PerformanceServer"),
    "http-server-batched": (ROOT, "HTTPServerPerformanceServer"),
    "vapor-batched": (ROOT, "PerformanceServer"),
}
EXPECTED = {
    "tiny": b"OK",
    "small": b"x" * 1024,
    "large": b"x" * (64 * 1024),
    "json": {"id": 1, "name": "benchmark", "tags": ["a", "b", "c"]},
    "stream": b"y" * (16 * 1024),
    "file": b"z" * (1 << 20),
}
# Ignore proxy environment variables for these strictly local requests.
HTTP = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def command_text(command):
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return result.stdout.strip()


def positive_int(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def check_response(url, route):
    with HTTP.open(url, timeout=5) as response:
        body = response.read()
        if response.status != 200:
            raise RuntimeError(f"{url}: HTTP {response.status}")
        actual = json.loads(body) if route == "json" else body
        if actual != EXPECTED[route]:
            raise RuntimeError(f"{url}: incorrect response body ({len(body)} bytes)")
        if route == "json" and response.headers.get_content_type() != "application/json":
            raise RuntimeError(f"{url}: incorrect JSON content type")
        return {"body_bytes": len(body), "headers": dict(response.headers)}


def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def report(results, output):
    lines = [
        "# Local HTTP performance comparison", "",
        "Median of repeated runs; ranges are min–max throughput. Latencies are medians of each run's percentiles, not pooled percentiles.", "",
        "| Route | Framework | req/s | req/s range | p50 ms | p99 ms |",
        "| --- | --- | ---: | ---: | ---: | ---: |",
    ]
    for route in dict.fromkeys(row["route"] for row in results):
        for framework in SERVERS:
            rows = [r for r in results if r["framework"] == framework and r["route"] == route]
            if not rows:
                continue
            rates = [r["requests_per_second"] for r in rows]
            p50 = statistics.median(r["p50_us"] for r in rows) / 1000
            p99 = statistics.median(r["p99_us"] for r in rows) / 1000
            lines.append(f"| {route} | {framework} | {statistics.median(rates):,.0f} | {min(rates):,.0f}–{max(rates):,.0f} | {p50:.3f} | {p99:.3f} |")
    (output / "summary.md").write_text("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("routes", nargs="*", default=list(EXPECTED))
    parser.add_argument("--frameworks", nargs="+", choices=SERVERS, default=["vapor", "vapor4", "hummingbird"])
    parser.add_argument("--binary", action="append", default=[], metavar="FRAMEWORK=PATH", help="use an explicitly saved release executable (requires --skip-build)")
    parser.add_argument("--duration", type=positive_int, default=10, help="seconds per measured run")
    parser.add_argument("--warmup", type=positive_int, default=3, help="seconds before each measured run")
    parser.add_argument("--repeats", type=positive_int, default=3)
    parser.add_argument("--connections", type=positive_int, default=64)
    parser.add_argument("--threads", type=positive_int, default=4, help="wrk threads")
    parser.add_argument("--server-threads", type=positive_int, default=4, help="NIO event-loop and blocking-pool threads")
    parser.add_argument("--port", type=int, default=18080)
    parser.add_argument("--skip-build", action="store_true", help="use existing release binaries; rebuild after source changes")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    overrides = {}
    for override in args.binary:
        name, separator, path = override.partition("=")
        if not args.skip_build or not separator or name not in args.frameworks:
            parser.error("--binary requires --skip-build and FRAMEWORK=PATH for a selected framework")
        overrides[name] = Path(path).resolve()
    if any(name.startswith("http-server") for name in args.frameworks) and "file" in args.routes:
        parser.error("http-server supports tiny, small, large, json, stream; specify routes explicitly")
    if any(name.endswith("-batched") and name not in overrides for name in args.frameworks):
        parser.error("batched experiments require an explicit --binary snapshot")
    if "vapor-direct" in args.frameworks and any(route in args.routes for route in ["file", "stream"]):
        parser.error("vapor-direct supports tiny, small, large, json; specify routes explicitly")
    if any(route not in EXPECTED for route in args.routes):
        parser.error(f"routes must be drawn from {', '.join(EXPECTED)}")
    if len(set(args.frameworks)) != len(args.frameworks):
        parser.error("frameworks must be unique")
    if args.connections < args.threads or args.connections % args.threads:
        parser.error("connections must be a positive multiple of wrk threads")
    if not 1024 <= args.port <= 65535:
        parser.error("port must be between 1024 and 65535")
    if not shutil.which("wrk"):
        parser.error("wrk is required (brew install wrk)")
    output = args.output or ROOT / "Results" / datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    results = []
    try:
        # All compilation finishes before any load generation starts.
        binaries = {}
        for name in args.frameworks:
            package, product = SERVERS[name]
            if not args.skip_build:
                print(f"Building {name}…", flush=True)
                with (output / f"build-{name}.log").open("w") as log:
                    subprocess.run(["swift", "build", "--package-path", str(package), "-c", "release", "--product", product], stdout=log, stderr=subprocess.STDOUT, check=True)
            binary = overrides.get(name, package / ".build" / "release" / product)
            if not binary.is_file():
                raise RuntimeError(f"Missing release binary: {binary}")
            binaries[name] = binary
            lock = package / "Package.resolved"
            if lock.exists():
                shutil.copyfile(lock, output / f"dependencies-{name}.json")

        environment = dict(os.environ, PERF_HOST="127.0.0.1", PERF_PORT=str(args.port),
                           PERF_FILE=str(output / "fixture.bin"),
                           NIO_SINGLETON_GROUP_LOOP_COUNT=str(args.server_threads),
                           NIO_SINGLETON_BLOCKING_POOL_THREAD_COUNT=str(args.server_threads))
        Path(environment["PERF_FILE"]).write_bytes(EXPECTED["file"])
        metadata = {
            "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "arguments": {k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()},
            "platform": platform.platform(), "swift": command_text(["swift", "--version"]),
            "hardware": command_text(["sysctl", "hw.model", "hw.ncpu", "hw.memsize", "machdep.cpu.brand_string"]),
            "wrk": command_text(["wrk", "--version"]),
            "vapor_commit": command_text(["git", "-C", str(ROOT), "rev-parse", "HEAD"]),
            "git_status": command_text(["git", "-C", str(ROOT), "status", "--short"]),
            "binary_sha256": {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in binaries.items()},
            "binary_paths": {name: str(path) for name, path in binaries.items()},
            "driver_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "source_sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in list((ROOT / "Sources").rglob("*.swift")) + list((ROOT / "Comparisons" / "Sources").rglob("*.swift"))},
            "environment": {k: environment[k] for k in ["PERF_HOST", "PERF_PORT", "NIO_SINGLETON_GROUP_LOOP_COUNT", "NIO_SINGLETON_BLOCKING_POOL_THREAD_COUNT"]},
            "protocol": "HTTP/1.1, plaintext, keep-alive, no pipelining; loopback client and server",
        }
        (output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
        print(f"Results: {output}", flush=True)
        for repeat in range(args.repeats):
            # Rotate framework order to reduce systematic warm-machine/order bias.
            offset = repeat % len(args.frameworks)
            order = args.frameworks[offset:] + args.frameworks[:offset]
            for name in order:
                # Refuse to accidentally benchmark a server already on this port.
                with socket.socket() as probe:
                    # Previous runs can leave accepted sockets in TIME_WAIT.
                    probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                    probe.bind(("127.0.0.1", args.port))
                    probe.listen(1)
                log_path = output / f"server-{repeat + 1}-{name}.log"
                with log_path.open("w") as log:
                    server_environment = dict(environment, PERF_MODE={"vapor-direct": "direct", "vapor-no-middleware": "no-middleware"}.get(name, "default"))
                    process = subprocess.Popen([str(binaries[name])], env=server_environment, stdout=log, stderr=subprocess.STDOUT)
                    try:
                        base = f"http://127.0.0.1:{args.port}/bench/"
                        deadline = time.monotonic() + 30
                        while True:
                            if process.poll() is not None:
                                raise RuntimeError(f"{name} exited during startup; see {log_path}")
                            try:
                                check_response(base + "tiny", "tiny")
                                break
                            except (OSError, ValueError):
                                if time.monotonic() >= deadline:
                                    raise RuntimeError(f"{name} failed to start; see {log_path}")
                                time.sleep(0.1)
                        for route in args.routes:
                            validation = check_response(base + route, route)
                            wrk = ["wrk", f"-t{args.threads}", f"-c{args.connections}", "--timeout", "2s", "--latency", "-s", str(ROOT / "wrk-metrics.lua")]
                            for phase, duration in [("warmup", args.warmup), ("measured", args.duration)]:
                                command = wrk + [f"-d{duration}s", base + route]
                                run = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=duration + 15, check=True)
                                (output / f"{repeat + 1}-{name}-{route}-{phase}.txt").write_text(run.stdout)
                                metrics = json.loads(next(line.removeprefix("METRICS ") for line in run.stdout.splitlines() if line.startswith("METRICS ")))
                                if metrics["requests"] == 0 or any(metrics[key] for key in ["connect_errors", "read_errors", "write_errors", "status_errors", "timeouts"]):
                                    raise RuntimeError(f"{name}/{route} {phase} had errors: {metrics}")
                            row = dict(metrics, framework=name, route=route, repeat=repeat + 1,
                                       requests_per_second=metrics["requests"] * 1e6 / metrics["duration_us"],
                                       validation=validation, command=command)
                            results.append(row)
                            (output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
                            print(f"{repeat + 1}/{args.repeats} {name:12} {route:7} {row['requests_per_second']:10,.0f} req/s  p99 {row['p99_us'] / 1000:.3f} ms", flush=True)
                            if process.poll() is not None:
                                raise RuntimeError(f"{name} exited during measurement")
                    finally:
                        stop(process)
        report(results, output)
    finally:
        (output / "fixture.bin").unlink(missing_ok=True)
    print(f"Summary: {output / 'summary.md'}", flush=True)


if __name__ == "__main__":
    main()
