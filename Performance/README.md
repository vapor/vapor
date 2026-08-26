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

Payloads are constants built at start-up, so a run measures Vapor rather than handler work. The
1 MiB file is generated into the temp directory, so it is identical on every machine and checkout.

## Interpreting the numbers

`wrk` measures the whole stack - kernel networking, HTTP parsing, routing, serialisation - so it is
the right tool for *"how many requests per second can Vapor sustain"* and the wrong tool for
attributing a change to a particular line of code.

It is also **very** sensitive to machine state. A background build roughly halved throughput on the
same binary and route when this harness was written. Run it on an otherwise idle machine, and do not
read anything into a few percent between runs.

For changes you want to attribute, use `../Benchmarks`: instruction counts and `mallocCountTotal`
are deterministic (flat p0-p100 over thousands of samples) where wall-clock throughput is not.
