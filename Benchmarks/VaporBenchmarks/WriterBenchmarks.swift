import Benchmark
import Foundation
import NIOCore
import Vapor

// Exercises `ResponseBodyWriter`'s `Sequence<UInt8>` overload - the entry point existing code uses
// when it has bytes in an array rather than a span. The default implementation copies into a
// `ContiguousArray` before it can hand them over as a `RawSpan`; a writer that copies synchronously
// can borrow the sequence's own storage instead. These measure that difference.
private let arrayPayload = [UInt8](repeating: 0x78, count: 1024)
private let dataPayload = Data(repeating: 0x78, count: 1024)
private let chunks = 8

func writerBenchmarks() {
    Benchmark("writer/Sequence Array 1KiB x8") { benchmark in
        for _ in benchmark.scaledIterations {
            var body = try Response.Body(stream: { writer in
                for _ in 0..<chunks {
                    try await writer.write(arrayPayload)
                }
            }, count: chunks * 1024)
            blackHole(try await body.collect())
        }
    }

    Benchmark("writer/Sequence ArraySlice 1KiB x8") { benchmark in
        for _ in benchmark.scaledIterations {
            var body = try Response.Body(stream: { writer in
                for _ in 0..<chunks {
                    try await writer.write(arrayPayload[0..<1024])
                }
            }, count: chunks * 1024)
            blackHole(try await body.collect())
        }
    }

    Benchmark("writer/Sequence Data 1KiB x8") { benchmark in
        for _ in benchmark.scaledIterations {
            var body = try Response.Body(stream: { writer in
                for _ in 0..<chunks {
                    try await writer.write(dataPayload)
                }
            }, count: chunks * 1024)
            blackHole(try await body.collect())
        }
    }
}
