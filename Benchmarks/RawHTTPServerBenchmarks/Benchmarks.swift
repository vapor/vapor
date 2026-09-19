import AsyncHTTPClient
import BasicContainers
import Benchmark
import BenchmarkSupport
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

nonisolated(unsafe) private var serverTask: Task<Void, any Error>?
nonisolated(unsafe) private var serverURL = ""

private func setUpServer() async throws {
    let configuration = try NIOHTTPServerConfiguration(
        bindTarget: .hostAndPort(host: "127.0.0.1", port: 0),
        supportedHTTPVersions: [.http1_1], transportSecurity: .plaintext
    )
    let server = NIOHTTPServer(configuration: configuration)
    serverTask = Task { try await server.serve(handler: BenchmarkHandler()) }
    let addresses = try await server.listeningAddresses
    serverURL = "http://127.0.0.1:\(addresses[0].port)"
}

let benchmarks: @Sendable () -> Void = {
    LoggingSystem.bootstrap { _ in SwiftLogNoOpLogHandler() }
    Benchmark.defaultConfiguration = .init(
        metrics: [.instructions, .mallocCountTotal, .wallClock],
        warmupIterations: 3,
        scalingFactor: .kilo,
        maxDuration: .seconds(3)
    )
    configureSmokeRun()
    for route in ["status", "tiny", "json", "large", "stream"] {
        // Match Vapor's network fixture, including client, collection bound,
        // timed validation and scaling. Startup and shutdown stay outside timing.
        Benchmark("network/\(route)", configuration: .init(scalingFactor: .one)) { benchmark in
            let request = HTTPClientRequest(url: serverURL + "/bench/\(route)")
            for _ in benchmark.scaledIterations {
                let response = try await HTTPClient.shared.execute(request, timeout: .seconds(5))
                let body = try await response.body.collect(upTo: 131072)
                precondition(Int(response.status.code) == (route == "status" ? 204 : 200))
                blackHole(body)
            }
        } setup: {
            try await setUpServer()
            try await validateResponse(route: route, at: serverURL)
        } teardown: {
            serverTask?.cancel()
            _ = await serverTask?.result
            serverTask = nil
        }
    }
}
