import Benchmark
import Foundation
import Vapor

// Streaming bodies drive the writer once per chunk, so the interesting variable is chunk count
// rather than payload size. The first three hold the total payload at 64 KiB and vary only how many
// writes it takes to deliver, which isolates per-write overhead from the cost of moving the bytes.
//
// The rest fix the shape and vary which overload the body closure calls, so the cost of each door
// into `ResponseBodyWriter` is comparable: `String` and `Span` hand over borrowed bytes, while
// `Sequence` has to recover contiguous storage first.
private let chunk64k = String(repeating: "x", count: 64 * 1024)
private let chunk4k = String(repeating: "x", count: 4 * 1024)
private let chunk256 = String(repeating: "x", count: 256)
private let bytes4k = [UInt8](repeating: 0x78, count: 4 * 1024)

func streamingBenchmarks() {
    Benchmark("stream/1 x 64KiB") { benchmark in
        for _ in benchmark.scaledIterations {
            var body = Response.Body(stream: { writer in
                try await writer.write(chunk64k)
            }, count: 64 * 1024)
            blackHole(try await body.collect())
        }
    }

    Benchmark("stream/16 x 4KiB") { benchmark in
        for _ in benchmark.scaledIterations {
            var body = Response.Body(stream: { writer in
                for _ in 0..<16 { try await writer.write(chunk4k) }
            }, count: 64 * 1024)
            blackHole(try await body.collect())
        }
    }

    Benchmark("stream/256 x 256B") { benchmark in
        for _ in benchmark.scaledIterations {
            var body = Response.Body(stream: { writer in
                for _ in 0..<256 { try await writer.write(chunk256) }
            }, count: 64 * 1024)
            blackHole(try await body.collect())
        }
    }

    Benchmark("stream/16 x 4KiB via Span") { benchmark in
        for _ in benchmark.scaledIterations {
            var body = Response.Body(stream: { writer in
                for _ in 0..<16 { try await writer.write(bytes4k.span) }
            }, count: 64 * 1024)
            blackHole(try await body.collect())
        }
    }

    Benchmark("stream/16 x 4KiB via Sequence") { benchmark in
        for _ in benchmark.scaledIterations {
            var body = Response.Body(stream: { writer in
                for _ in 0..<16 { try await writer.write(bytes4k) }
            }, count: 64 * 1024)
            blackHole(try await body.collect())
        }
    }

    // End to end: routing, middleware and the drain in `run(_:)`, not just the body in isolation.
    Benchmark("stream/responder 16 x 4KiB") { benchmark in
        let call = RequestCall(.get, "/stream")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("stream") { _ -> Response in
                Response(
                    body: .init(
                        stream: { writer in
                            for _ in 0..<16 { try await writer.write(chunk4k) }
                        },
                        count: 64 * 1024
                    )
                )
            }
        }
    } teardown: {
        try await tearDownApplication()
    }
}
