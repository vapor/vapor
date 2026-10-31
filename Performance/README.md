# Performance

A standalone Vapor app plus a `wrk` driver, for load-testing the request/response path on demand.
Separate package (like `Benchmarks/`), so it never affects the main build.

## Usage

```sh
cd Performance
./run-wrk.sh                       # every route
./run-wrk.sh tiny large            # selected routes
DURATION=30s CONNECTIONS=256 ./run-wrk.sh
```

Requires `wrk` (`brew install wrk`). The script builds the server, starts it, waits until it is
actually serving, runs a discarded warm-up before each measurement, and shuts it down afterwards.

## Routes

| route | body | what it tells you |
| --- | --- | --- |
| `/bench/tiny` | 2 B | throughput ceiling - overhead only, payload is irrelevant |
| `/bench/small` | 1 KiB | typical small buffered response |
| `/bench/large` | 64 KiB | buffered response where copying dominates |
| `/bench/json` | 48 B | `Content` encoding |
| `/bench/stream` | 16 KiB | streaming writer, 16 awaited chunks |
| `/bench/file` | 1 MiB | real `FileIO` streaming, 8 x 128 KiB chunks |

## Interpreting the numbers

**Note**: the numbers generated here can change depending on what else your computer is doing and will vary machine to machine. This is just a rough guide to ensure we don't regress and to give us some end-to-end saturation. We have actual benchmarks in `Benchmarks/` that give actual consistent measurements.