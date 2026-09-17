# Allocation and instruction benchmarks

Requires Swift 6.4. The suite uses benchmark 1.36.2 and measures instructions, malloc counts and wall clock time. On macOS, instructions come from `proc_pid_rusage`; on Linux the host must expose perf counters. A missing or zero counter is unavailable, never an improvement.

```sh
swift package --package-path Benchmarks --allow-writing-to-package-directory benchmark list
NIO_SINGLETON_GROUP_LOOP_COUNT=4 NIO_SINGLETON_BLOCKING_POOL_THREAD_COUNT=4 \
  swift package --package-path Benchmarks --allow-writing-to-package-directory benchmark \
  --filter '^(e2e|network)/.*' --no-progress --scale
```

`e2e/` covers creation of the request, routing, default middleware, response encoding and consumption of the body. It shares the application's content configuration as the real server does. The sink copies bytes, so its cost is included. The five workloads match `Performance/compare.py`: 204 without a body, 2-byte string, per-request JSON encoding, 64 KiB string and 16 writes of 1 KiB.

`network/` runs the real HTTP server and AsyncHTTPClient in the same process over a persistent loopback connection. **Its instruction/allocation totals include both client and server**, plus transport bookkeeping. This catches HTTP-server changes that an in-memory responder benchmark cannot see. It is not a server-only allocation claim or a saturation throughput test. `Performance/compare.py` uses a separate, uninstrumented release server for the latter.

The remaining suites cover authentication, parameter and wildcard routing, middleware depth, content and query decoding, serialization, writer overloads and streaming chunk sizes. Hummingbird's [router benchmarks](https://github.com/hummingbird-project/hummingbird/blob/2.26.0/Benchmarks/HummingbirdBenchmarks/RouterBenchmarks.swift) inspired the full response-body consumption; its upstream no-op sink and reused request/context have different scope, so raw numbers must not be compared directly.
