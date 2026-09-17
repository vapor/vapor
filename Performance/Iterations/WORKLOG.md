# Twenty-iteration optimization study

Requested scope: local-only commits, no pushes; rebase benchmarks onto main, then create a separate optimization branch. Measure status-only (204), tiny (2 B), JSON, large (64 KiB), streaming (16 × 1 KiB), retaining the additional small and file controls. Prefer batching, borrowing and readable changes. Report regressions and unavailable metrics honestly.

## Preparation

- Main fetched at 5dfe8b81197d9edfe0298a3961ee119c11e413fd.
- Original benchmarks tip backed up as codex/benchmarks-before-rebase (1794c1623).
- Existing investigation preserved at codex/performance-investigation-checkpoint (9f96faf24).
- Benchmarks rebased, retaining main's current request/server lifecycle implementation.
- Benchmark library pinned to 1.36.2. macOS instruction counts use proc_pid_rusage; allocations use the library's malloc interposer.
- In-memory and actual HTTP end-to-end counter benchmarks added. The network counter benchmarks include the in-process AsyncHTTPClient client; wrk throughput uses a separate uninstrumented executable.

## Measurement rules

Compile and test before measuring; run loads serially. Save release binary hashes, source/dependency revisions, raw samples, counters and command lines. Use repeated workloads and interpret small differences as noise. All routes must validate exact bodies (semantic JSON) and expected status; errors invalidate a run. Keep server semantics and safety checks intact. Each iteration gets a local source commit, measurements and a short interpretation. A candidate that regresses is recorded and reverted rather than described as an improvement.

## Progress

Benchmark suite compiles; release servers compile. Preparation regression run: 160 tests in 6 suites passed with 2 pre-existing known issues in the Connection: close test. Logs preserved with the baseline. No optimization iterations completed yet.
