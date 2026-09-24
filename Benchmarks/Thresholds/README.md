# Runner thresholds

Manually dispatch the benchmark workflow with `record_thresholds` enabled to
export the `benchmark-thresholds` artifact from the benchmark runner. Review and
commit its generated files here, retaining the directory layout:

- `instructions/`
- `allocations/`
- `cpu/`
- `wall-clock/`

Normal runs require committed thresholds. Every measured fixture in every mode
must have matching metrics; partial sets fail the comparison. Recording
is always explicit and reports that no performance comparison was performed.
Never substitute local or smoke measurements.

See [the benchmark README](../README.md#recording-the-first-thresholds) for the
recording and update process.

## Current recording

These 576 p90 threshold files cover 144 fixtures in each of the four modes. They
were exported unchanged from [run 35864774350](https://github.com/vapor/vapor/actions/runs/35864774350)
on 2026-09-23, using:

- Vapor commit `94846f5f630b50bac498102fdf93930142ef9afd`.
- Shared CI commit `ad78413e13bebb9158083aa226608e028754106b`.
- An `m8g.large` ARM64 Graviton4 runner with two vCPUs and 8 GiB RAM.
- Swift 6.4 release in `swift:6.4-noble`, image digest
  `sha256:64bab762bc73a3fda6d9ebc559258bd6d7660c10a705bb25ecacad2f99d066f9`.
- Two NIO event-loop threads and two blocking-pool threads, with allocation
  counting enabled only for the allocations configuration.

All instruction and wall-clock thresholds are positive. Six allocation thresholds
and 52 CPU thresholds are zero. The CPU results reflect the Linux CPU timer's
coarse resolution; relative comparisons against those zero baselines do not
provide useful regression detection. Preserve these recorded values rather than
substituting estimates, and use the instruction and wall-clock results alongside
them. See the benchmark README for the limitations of zero reference values.

### Resolved dependencies

Versions reported by the recording run:

| Package | Version |
| --- | --- |
| async-http-client | 1.35.0 |
| benchmark | 1.36.2 |
| console-kit | 5.0.0-beta.2 |
| hdrhistogram-swift | 0.2.0 |
| malloc-interposer | 1.4.0 |
| multipart-kit | 5.0.0-beta.2 |
| routing-kit | 5.0.0-beta.3 |
| swift-algorithms | 1.2.1 |
| swift-argument-parser | 1.8.2 |
| swift-asn1 | 1.7.3 |
| swift-async-algorithms | 1.1.5 |
| swift-atomics | 1.3.1 |
| swift-certificates | 1.21.0 |
| swift-collections | 1.6.0 |
| swift-configuration | 1.2.1 |
| swift-crypto | 5.0.0 |
| swift-distributed-tracing | 1.5.0 |
| swift-http-api-proposal | 0.2.1 |
| swift-http-server | 0.2.0 |
| swift-http-structured-headers | 1.7.0 |
| swift-http-types | 1.8.0 |
| swift-log | 1.15.1 |
| swift-metrics | 2.11.0 |
| swift-nio | 2.103.0 |
| swift-nio-extras | 1.35.1 |
| swift-nio-http2 | 1.46.0 |
| swift-nio-ssl | 2.37.5 |
| swift-nio-transport-services | 1.28.0 |
| swift-numerics | 1.1.1 |
| swift-service-context | 1.3.0 |
| swift-service-lifecycle | 2.12.0 |
| swift-syntax | 602.0.0 |
| swift-system | 1.8.1 |
| TextTable | 0.0.2 |
