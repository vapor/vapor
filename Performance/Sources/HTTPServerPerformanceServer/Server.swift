import BasicContainers
import Foundation
import HTTPTypes
import Logging
import NIOHTTPServer

/// The same buffered and streaming workloads without Vapor's request adapter,
/// router, middleware, or response encoding protocols. JSON still encodes per request.
struct BenchmarkHandler: HTTPServerRequestHandler {
    let small = String(repeating: "x", count: 1024)
    let large = String(repeating: "x", count: 64 * 1024)
    let chunk = String(repeating: "y", count: 1024)

    struct Payload: Encodable {
        var id = 1
        var name = "benchmark"
        var tags = ["a", "b", "c"]
    }

    func handle(
        request: HTTPRequest,
        requestContext: consuming NIOHTTPServer.RequestContext,
        reader: consuming sending NIOHTTPServer.Reader,
        responseSender: consuming sending NIOHTTPServer.ResponseSender
    ) async throws {
        var reader = consume reader
        if request.path == "/bench/status" {
            var empty = UniqueArray<UInt8>()
            try await responseSender.sendAndFinish(.init(status: .noContent), buffer: &empty)
        } else if request.path == "/bench/stream" {
            var writer = try await responseSender.send(.init(status: .ok, headerFields: [.contentLength: "16384"]))
            for _ in 0..<16 {
                var buffer = UniqueArray<UInt8>(copying: chunk.utf8)
                try await writer.write(buffer: &buffer)
            }
            var empty = UniqueArray<UInt8>()
            try await writer.finish(buffer: &empty, finalElement: nil)
        } else if request.path == "/bench/json" {
            let data = try JSONEncoder().encode(Payload())
            var body = UniqueArray<UInt8>(copying: data)
            try await responseSender.sendAndFinish(
                .init(status: .ok, headerFields: [.contentType: "application/json; charset=utf-8", .contentLength: "\(data.count)"]),
                buffer: &body
            )
        } else {
            let value: String
            let status: HTTPResponse.Status
            switch request.path {
            case "/bench/tiny": (value, status) = ("OK", .ok)
            case "/bench/small": (value, status) = (small, .ok)
            case "/bench/large": (value, status) = (large, .ok)
            default: (value, status) = ("Not found", .notFound)
            }
            var body = UniqueArray<UInt8>(copying: value.utf8)
            try await responseSender.sendAndFinish(
                .init(status: status, headerFields: [.contentType: "text/plain; charset=utf-8", .contentLength: "\(value.utf8.count)"]),
                buffer: &body
            )
        }
        // Observe request end so the HTTP server can reuse this connection.
        // Like Vapor's adapter, this happens after sending the response.
        var finished = false
        repeat {
            finished = try await reader.read { _, trailers in trailers != nil }
        } while !finished
    }
}

@main
struct HTTPServerPerformanceServer {
    static func main() async throws {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = .error
            return handler
        }
        let environment = ProcessInfo.processInfo.environment
        let server = NIOHTTPServer(configuration: try .init(
            bindTarget: .hostAndPort(host: environment["PERF_HOST"] ?? "127.0.0.1", port: Int(environment["PERF_PORT"] ?? "") ?? 8080),
            supportedHTTPVersions: [.http1_1],
            transportSecurity: .plaintext
        ))
        try await server.serve(handler: BenchmarkHandler())
    }
}
