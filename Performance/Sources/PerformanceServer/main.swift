import Foundation
import HTTPTypes
import Logging
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

let filePath = ProcessInfo.processInfo.environment["PERF_FILE"] ?? NSTemporaryDirectory() + "vapor-perf-1MiB.bin"
if !FileManager.default.fileExists(atPath: filePath) {
    try Data(repeating: 0x7A, count: 1 << 20).write(to: URL(fileURLWithPath: filePath))
}

LoggingSystem.bootstrap { label in
    var handler = StreamLogHandler.standardError(label: label)
    handler.logLevel = .error
    return handler
}

// Diagnostic modes isolate routing/middleware from the HTTP adapter.
struct DirectResponder: Responder {
    let small = String(repeating: "x", count: 1024)
    let large = String(repeating: "x", count: 64 * 1024)

    func respond(to request: Request) async throws -> Response {
        switch request.url.path {
        case "/bench/status": try await HTTPResponse.Status.noContent.encodeResponse(for: request)
        case "/bench/tiny": try await "OK".encodeResponse(for: request)
        case "/bench/small": try await small.encodeResponse(for: request)
        case "/bench/large": try await large.encodeResponse(for: request)
        case "/bench/json": try await Payload(id: 1, name: "benchmark", tags: ["a", "b", "c"]).encodeResponse(for: request)
        default: throw Abort(.notFound)
        }
    }
}

let mode = ProcessInfo.processInfo.environment["PERF_MODE"] ?? "default"
let app = try await Application(.production, services: .init(
    responder: mode == "direct" ? .provided(DirectResponder()) : .default
))
if mode == "no-middleware" {
    app.middleware = .init()
}
app.serverConfiguration.address = .hostname(host, port: port)

app.get("bench", "status") { _ in HTTPResponse.Status.noContent }
app.get("bench", "tiny") { _ in "OK" }
app.get("bench", "small") { _ in small }
app.get("bench", "large") { _ in large }
app.get("bench", "json") { _ in json }

app.get("bench", "stream") { _ -> Response in
    Response(
        body: try .init(
            stream: { writer in
                for _ in 0..<16 {
                    try await writer.write(chunk)
                }
            }, count: 16 * 1024))
}

app.get("bench", "file") { req in
    try await app.fileio.streamFile(at: filePath, for: req)
}

print("performance server listening on http://\(host):\(port)")
try await app.start()
