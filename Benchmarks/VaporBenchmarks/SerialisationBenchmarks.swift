import Benchmark
import Foundation
import NIOCore
import Vapor

// Isolates the buffered serialisation step: take a `Response.Body` and produce the bytes that
// `HTTPServerHandler` hands to the transport. The `response/*` benchmarks cover this as part of a
// whole request; these measure it on its own, so a change in how a body is turned into bytes shows
// up without routing and middleware costs on top. Sized to show both the fixed per-response cost
// (1 KiB) and the part that scales with the payload (64 KiB).
private let payload1k = String(repeating: "x", count: 1024)
private let payload64k = String(repeating: "x", count: 64 * 1024)
private let data1k = Data(String(repeating: "x", count: 1024).utf8)

@inline(never)
private func serialise(_ body: Response.Body) async throws -> Int {
    var out = [UInt8]()
    out.reserveCapacity(body.count)
    if let buffer = body.buffer, buffer.readableBytes > 0 {
        out.append(contentsOf: buffer.readableBytesView)
    }
    return out.count
}

func serialisationBenchmarks() {
    Benchmark("serialise/String 1KiB") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(try await serialise(Response.Body(string: payload1k)))
        }
    }

    Benchmark("serialise/String 64KiB") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(try await serialise(Response.Body(string: payload64k)))
        }
    }

    Benchmark("serialise/Data 1KiB") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(try await serialise(Response.Body(data: data1k)))
        }
    }
}
