#!/usr/bin/env python3
"""Build and compare matching localhost HTTP/1.1 workloads. Python standard library only."""

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import resource
import shutil
import socket
import statistics
import subprocess
import time
import urllib.request
from urllib.parse import quote

ROOT = Path(__file__).resolve().parent
DEFAULT_ROUTES = ["status", "tiny", "small", "large", "json", "stream", "file"]
SERVERS = {
    "vapor": (ROOT, "PerformanceServer"),
    "vapor4": (ROOT / "Comparisons", "Vapor4PerformanceServer"),
    "hummingbird": (ROOT / "Comparisons", "HummingbirdPerformanceServer"),
    "http-server": (ROOT, "HTTPServerPerformanceServer"),
    "vapor-direct": (ROOT, "PerformanceServer"),
    "vapor-no-middleware": (ROOT, "PerformanceServer"),
    "vapor-baseline": (ROOT, "PerformanceServer"),
    "http-server-baseline": (ROOT, "HTTPServerPerformanceServer"),
}
EXPECTED = {
    "status": b"",
    "tiny": b"OK",
    "small": b"x" * 1024,
    "large": b"x" * (64 * 1024),
    "json": {"id": 1, "name": "benchmark", "tags": ["a", "b", "c"]},
    "stream": b"y" * (16 * 1024),
    "file": b"z" * (1 << 20),
    "routing-parameter/42": b"42",
    "routing-parameter/a-long-user-identifier-without-escapes": b"a-long-user-identifier-without-escapes",
    "routing-catchall/a/b/c": b"a/b/c",
    "routing-shadowed/f%69xed/end": b"OK",
    "routing-alternatives/f%69xed.txt/end": b"OK",
    "routing-partial/report.txt": b"report",
    "routing-backtrack/fixed/end": b"fixed",

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
        if response.status != (204 if route == "status" else 200):
            raise RuntimeError(f"{url}: HTTP {response.status}")
        actual = json.loads(body) if route == "json" else body
        if actual != EXPECTED[route]:
            raise RuntimeError(f"{url}: incorrect response body ({len(body)} bytes)")
        if route == "json" and response.headers.get_content_type() != "application/json":
            raise RuntimeError(f"{url}: incorrect JSON content type")
        return {"body_bytes": len(body), "headers": dict(response.headers)}


def cpu_seconds(text):
    """Parse ps cumulative process CPU time (days and fractional seconds optional)."""
    days, separator, clock = text.strip().partition('-')
    if not separator:
        clock, days = days, '0'
    parts = clock.split(':')
    if len(parts) not in [2, 3]:
        raise ValueError(f'Unrecognized ps CPU time: {text!r}')
    seconds = float(parts[-1]) + 60 * int(parts[-2]) + 86400 * int(days)
    if len(parts) == 3:
        seconds += 3600 * int(parts[0])
    return seconds


def server_cpu_snapshot(pid):
    value = subprocess.check_output(['ps', '-p', str(pid), '-o', 'time='], text=True).strip()
    return value, cpu_seconds(value)


def child_cpu_seconds():
    value = resource.getrusage(resource.RUSAGE_CHILDREN)
    return value.ru_utime + value.ru_stime


def parse_metrics(output):
    lines = [line.removeprefix("METRICS ") for line in output.splitlines() if line.startswith("METRICS ")]
    if len(lines) != 1:
        raise RuntimeError("Expected one wrk METRICS record")
    metrics = json.loads(lines[0])
    keys = ["requests", "duration_us", "bytes", "p50_us", "p99_us", "connect_errors", "read_errors", "write_errors", "status_errors", "timeouts"]
    if any(type(metrics.get(key)) is not int or metrics[key] < 0 for key in keys):
        raise RuntimeError(f"Invalid wrk metrics: {metrics}")
    if not metrics["requests"] or not metrics["duration_us"] or any(metrics[key] for key in keys[5:]):
        raise RuntimeError(f"Empty or failed wrk measurement: {metrics}")
    return metrics


def stop(process, grace_seconds=10):
    # Teardown is outside all wrk and CPU measurement intervals. Only this
    # harness-owned child is signalled; always reap it before the next server.
    started = time.monotonic()
    forced = False
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=grace_seconds)
        except subprocess.TimeoutExpired:
            forced = True
            process.kill()
            process.wait()
    return dict(exit_code=process.returncode, forced=forced,
                grace_seconds=grace_seconds, elapsed_seconds=time.monotonic() - started)


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
    if results and all("server_cpu_us_per_request" in r for r in results):
        lines += ["", "## Process CPU diagnostics", "",
                  "CPU time summed across each process's threads, divided by completed requests. "
                  "The server uses cumulative ps time (centisecond precision on this Mac); "
                  "wrk uses child rusage. Samples include connection setup/teardown around the "
                  "measured load and exclude warmup. These are CPU costs, not latency or utilization percentages.", "",
                  "| Route | Framework | Server CPU µs/request | Client CPU µs/request |",
                  "| --- | --- | ---: | ---: |"]
        for route in dict.fromkeys(r["route"] for r in results):
            for framework in dict.fromkeys(r["framework"] for r in results):
                rows = [r for r in results if r["framework"] == framework and r["route"] == route]
                if rows:
                    lines.append(f"| {route} | {framework} | "
                                 f"{statistics.median(r['server_cpu_us_per_request'] for r in rows):.2f} | "
                                 f"{statistics.median(r['client_cpu_us_per_request'] for r in rows):.2f} |")
    (output / "summary.md").write_text("\n".join(lines) + "\n")


def schedule(frameworks, routes, repeats, interleave_routes):
    for repeat in range(repeats):
        # A full cycle gives each framework every position for each workload.
        groups = [[route] for route in routes] if interleave_routes else [routes]
        for route_index, group in enumerate(groups):
            offset = (repeat + route_index) % len(frameworks)
            for name in frameworks[offset:] + frameworks[:offset]:
                yield repeat, name, group


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("routes", nargs="*", default=DEFAULT_ROUTES, help="routes: " + ", ".join(EXPECTED).replace("%", "%%"))
    parser.add_argument("--frameworks", nargs="+", choices=SERVERS, default=["vapor", "vapor4", "hummingbird"])
    parser.add_argument("--binary", action="append", default=[], metavar="FRAMEWORK=PATH", help="use an explicitly saved release executable (requires --skip-build)")
    parser.add_argument("--duration", type=positive_int, default=10, help="seconds per measured run")
    parser.add_argument("--warmup", type=positive_int, default=3, help="seconds before each measured run")
    parser.add_argument("--repeats", type=positive_int, default=3)
    parser.add_argument("--connections", type=positive_int, default=64)
    parser.add_argument("--threads", type=positive_int, default=4, help="wrk threads")
    parser.add_argument("--server-threads", type=positive_int, default=4, help="NIO event-loop and blocking-pool threads")
    parser.add_argument("--port", type=int, default=18080)
    parser.add_argument("--shutdown-timeout", type=positive_int, default=10,
                        help="seconds to allow the owned server to exit after load; teardown is not measured")
    parser.add_argument("--wrk", type=Path, help="explicit load-generator executable; its resolved path and hash are recorded")
    parser.add_argument("--skip-build", action="store_true", help="use existing release binaries; rebuild after source changes")
    parser.add_argument("--interleave-routes", action="store_true",
                        help="restart each server per workload to put matching framework samples closer in time")
    parser.add_argument("--record-cpu", action="store_true",
                        help="record server cumulative CPU and wrk child CPU around each measured load")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if any(route.startswith("routing-") for route in args.routes) and any(
        name not in ["vapor", "vapor-baseline", "vapor-no-middleware"] for name in args.frameworks
    ):
        parser.error("routing diagnostics require --frameworks vapor, vapor-baseline or vapor-no-middleware")
    overrides = {}
    for override in args.binary:
        name, separator, path = override.partition("=")
        if not args.skip_build or not separator or name not in args.frameworks:
            parser.error("--binary requires --skip-build and FRAMEWORK=PATH for a selected framework")
        overrides[name] = Path(path).resolve()
    if any(name.startswith("http-server") for name in args.frameworks) and "file" in args.routes:
        parser.error("http-server supports tiny, small, large, json, stream; specify routes explicitly")
    if any(name.endswith("-baseline") and name not in overrides for name in args.frameworks):
        parser.error("baseline comparisons require an explicit --binary snapshot")
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
    wrk_command = str(args.wrk) if args.wrk is not None else shutil.which("wrk")
    if not wrk_command or not Path(wrk_command).is_file() or not os.access(wrk_command, os.X_OK):
        parser.error("an executable wrk is required (--wrk PATH or install it on PATH)")
    wrk_binary = Path(wrk_command).resolve()
    output = args.output or ROOT / "Results" / datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    results = []
    shutdowns = []
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
            "hardware": command_text(["sysctl", "hw.model", "hw.ncpu", "hw.memsize", "machdep.cpu.brand_string"] if platform.system() == "Darwin" else ["lscpu"]),
            "wrk": command_text([str(wrk_binary), "--version"]),
            "wrk_binary_path": str(wrk_binary),
            "wrk_binary_sha256": hashlib.sha256(wrk_binary.read_bytes()).hexdigest(),
            "vapor_commit": command_text(["git", "-C", str(ROOT), "rev-parse", "HEAD"]),
            "git_status": command_text(["git", "-C", str(ROOT), "status", "--short"]),
            "binary_sha256": {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in binaries.items()},
            "binary_paths": {name: str(path) for name, path in binaries.items()},
            "driver_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "source_sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in list((ROOT / "Sources").rglob("*.swift")) + list((ROOT / "Comparisons" / "Sources").rglob("*.swift"))},
            "environment": {k: environment[k] for k in ["PERF_HOST", "PERF_PORT", "NIO_SINGLETON_GROUP_LOOP_COUNT", "NIO_SINGLETON_BLOCKING_POOL_THREAD_COUNT"]},
            "protocol": "HTTP/1.1, plaintext, keep-alive, no pipelining; loopback client and server",
            "cpu_scope": "Optional process CPU deltas around measured wrk only; server uses ps time (platform precision), client uses child rusage. Includes measured connection setup/teardown, excludes warmup. Diagnostic commands run outside the measured load.",
        }
        (output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
        print(f"Results: {output}", flush=True)
        for repeat, name, routes in schedule(args.frameworks, args.routes, args.repeats, args.interleave_routes):
            # Refuse to accidentally benchmark a server already on this port.
            with socket.socket() as probe:
                # Previous runs can leave accepted sockets in TIME_WAIT.
                probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                probe.bind(("127.0.0.1", args.port))
                probe.listen(1)
            suffix = "-" + quote(routes[0], safe="") if args.interleave_routes else ""
            log_path = output / f"server-{repeat + 1}-{name}{suffix}.log"
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
                    for route in routes:
                        validation = check_response(base + route, route)
                        wrk = [str(wrk_binary), f"-t{args.threads}", f"-c{args.connections}", "--timeout", "2s", "--latency", "-s", str(ROOT / "wrk-metrics.lua")]
                        for phase, duration in [("warmup", args.warmup), ("measured", args.duration)]:
                            command = wrk + [f"-d{duration}s", base + route]
                            if args.record_cpu and phase == "measured":
                                server_before_text, server_before = server_cpu_snapshot(process.pid)
                                client_before = child_cpu_seconds()
                            run = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=duration + 15, check=True)
                            if args.record_cpu and phase == "measured":
                                # Read rusage before launching ps, so only wrk is counted as a child.
                                client_cpu = child_cpu_seconds() - client_before
                                server_after_text, server_after = server_cpu_snapshot(process.pid)
                                server_cpu = server_after - server_before
                                if min(client_cpu, server_cpu) < 0:
                                    raise RuntimeError("Process CPU time moved backwards")
                            (output / f"{repeat + 1}-{name}-{quote(route, safe='')}-{phase}.txt").write_text(run.stdout)
                            metrics = parse_metrics(run.stdout)
                        row = dict(metrics, framework=name, route=route, repeat=repeat + 1,
                                   requests_per_second=metrics["requests"] * 1e6 / metrics["duration_us"],
                                   validation=validation, command=command)
                        if args.record_cpu:
                            row.update(server_cpu_seconds=server_cpu, client_cpu_seconds=client_cpu,
                                       server_cpu_us_per_request=server_cpu * 1e6 / metrics["requests"],
                                       client_cpu_us_per_request=client_cpu * 1e6 / metrics["requests"],
                                       server_cpu_ps_before=server_before_text, server_cpu_ps_after=server_after_text)
                        results.append(row)
                        (output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
                        print(f"{repeat + 1}/{args.repeats} {name:12} {route:7} {row['requests_per_second']:10,.0f} req/s  p99 {row['p99_us'] / 1000:.3f} ms", flush=True)
                        if process.poll() is not None:
                            raise RuntimeError(f"{name} exited during measurement")
                finally:
                    shutdown = stop(process, args.shutdown_timeout)
                    shutdowns.append(dict(repeat=repeat + 1, framework=name, routes=routes, **shutdown))
                    (output / "server-shutdowns.json").write_text(json.dumps(shutdowns, indent=2) + "\n")
        report(results, output)
    finally:
        (output / "fixture.bin").unlink(missing_ok=True)
    print(f"Summary: {output / 'summary.md'}", flush=True)


if __name__ == "__main__":
    main()
