import Foundation
import NIOCore
import Vapor

// A minimal Vapor app serving fixed-size responses, for load testing with `wrk` (see run-wrk.sh).
//
// Every route returns a constant payload built once at start-up, so a run measures Vapor's
// request/response path rather than whatever work a handler happens to do. Bind address is fixed
// (not port 0) so the load generator knows where to connect.

let port = Int(ProcessInfo.processInfo.environment["PERF_PORT"] ?? "") ?? 8080
let host = ProcessInfo.processInfo.environment["PERF_HOST"] ?? "127.0.0.1"

struct Payload: Content {
    var id: Int
    var name: String
    var tags: [String]
}

let small = String(repeating: "x", count: 1024)
let large = String(repeating: "x", count: 64 * 1024)
let chunk = String(repeating: "y", count: 1024)
let json = Payload(id: 1, name: "benchmark", tags: ["a", "b", "c"])

// A fixed 1 MiB file, written once, so file streaming measures the same bytes on every run and on
// every checkout - not whatever happens to be in the working tree.
let filePath = NSTemporaryDirectory() + "vapor-perf-1MiB.bin"
if !FileManager.default.fileExists(atPath: filePath) {
    try Data(repeating: 0x7A, count: 1 << 20).write(to: URL(fileURLWithPath: filePath))
}

let app = try await Application(.production)
app.serverConfiguration.address = .hostname(host, port: port)

// Buffered responses. `tiny` is the throughput ceiling: with a 2-byte body the number is dominated
// by accept/parse/route/respond overhead rather than anything to do with the payload.
app.get("bench", "tiny") { _ in "OK" }
app.get("bench", "small") { _ in small }
app.get("bench", "large") { _ in large }
app.get("bench", "json") { _ in json }

// Streaming: 16 x 1 KiB chunks with a declared length. Each write is awaited and backpressured, so
// this is deliberately slower than one buffered write of the same size.
app.get("bench", "stream") { _ -> Response in
    Response(body: .init(stream: { writer in
        for _ in 0..<16 {
            try await writer.write(ByteBuffer(string: chunk))
        }
    }, count: 16 * 1024))
}

// Real file streaming through FileIO - the path used when serving static files.
app.get("bench", "file") { req in
    try await req.fileio.streamFile(at: filePath)
}

print("performance server listening on http://\(host):\(port)")
try await app.run()
try await app.shutdown()
