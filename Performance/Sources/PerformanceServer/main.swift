import Foundation
import NIOCore
import RoutingKit
import Vapor

let port = Int(ProcessInfo.processInfo.environment["PERF_PORT"] ?? "") ?? 8080
let host = ProcessInfo.processInfo.environment["PERF_HOST"] ?? "127.0.0.1"

struct Payload: Content {
    var id: Int
    var name: String
    var tags: [String]
}

// Static responses for performance
let small = String(repeating: "x", count: 1024)
let large = String(repeating: "x", count: 64 * 1024)
let chunk = String(repeating: "y", count: 1024)
let json = Payload(id: 1, name: "benchmark", tags: ["a", "b", "c"])

let filePath = NSTemporaryDirectory() + "vapor-perf-1MiB.bin"
if !FileManager.default.fileExists(atPath: filePath) {
    try Data(repeating: 0x7A, count: 1 << 20).write(to: URL(fileURLWithPath: filePath))
}

let app = try await Application(.production)
app.serverConfiguration.address = .hostname(host, port: port)

app.get("bench", "tiny") { _ in "OK" }
app.get("bench", "small") { _ in small }
app.get("bench", "large") { _ in large }
app.get("bench", "json") { _ in json }

app.get("bench", "stream") { _ -> Response in
    Response(body: .init(stream: { writer in
        for _ in 0..<16 {
            try await writer.write(chunk)
        }
    }, count: 16 * 1024))
}

app.get("bench", "file") { req in
    try await req.fileio.streamFile(at: filePath)
}

print("performance server listening on http://\(host):\(port)")
try await app.run()
try await app.shutdown()
