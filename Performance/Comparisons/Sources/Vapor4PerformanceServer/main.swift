import Foundation
import Vapor

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
let filePath = ProcessInfo.processInfo.environment["PERF_FILE"] ?? NSTemporaryDirectory() + "vapor-perf-1MiB.bin"
if !FileManager.default.fileExists(atPath: filePath) {
    try Data(repeating: 0x7A, count: 1 << 20).write(to: URL(fileURLWithPath: filePath))
}

let app = try await Application.make(.production)
app.logger.logLevel = .error
app.http.server.configuration.hostname = host
app.http.server.configuration.port = port

app.get("bench", "tiny") { _ in "OK" }
app.get("bench", "small") { _ in small }
app.get("bench", "large") { _ in large }
app.get("bench", "json") { _ in json }
app.get("bench", "stream") { _ -> Response in
    Response(body: .init(managedAsyncStream: { writer in
        for _ in 0..<16 {
            try await writer.write(.buffer(ByteBuffer(string: chunk)))
        }
    }, count: 16 * 1024))
}
app.get("bench", "file") { req async throws -> Response in
    try await req.fileio.asyncStreamFile(at: filePath, chunkSize: 128 * 1024)
}

try await app.execute()
try await app.asyncShutdown()
