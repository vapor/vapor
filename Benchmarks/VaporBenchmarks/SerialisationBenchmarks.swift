import Benchmark
import Foundation
import NIOCore
import Vapor

// Models `HTTPServerHandler`'s buffered branch: take a `Response.Body` and produce the bytes handed
// to the transport. The `response/*` benchmarks stop at the responder and never reach this path,
// which is where the ByteBuffer-removal work actually changed the number of copies.
private let payload1k = String(repeating: "x", count: 1024)
private let payload64k = String(repeating: "x", count: 64 * 1024)
private let data1k = Data(String(repeating: "x", count: 1024).utf8)

@inline(never)
private func serialise(_ body: Response.Body) async throws -> Int {
    var out = [UInt8]()
    out.reserveCapacity(body.count)
    try await body.withStreamingBytes { span in
        span.withUnsafeBytes { unsafe out.append(contentsOf: $0) }
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
