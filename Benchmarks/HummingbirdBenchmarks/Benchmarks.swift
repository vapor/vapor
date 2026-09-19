import AsyncHTTPClient
import Benchmark
import BenchmarkSupport
import Foundation
import Hummingbird
import Logging
import NIOCore
import NIOPosix

private struct BenchmarkPayload: ResponseEncodable {
    var id = 1
    var name = "benchmark"
    var tags = ["a", "b", "c"]
}

private let largePayload = String(repeating: "x", count: 65536)
private let streamChunk = String(repeating: "y", count: 1024)
nonisolated(unsafe) private var serverTask: Task<Void, any Error>?
nonisolated(unsafe) private var serverURL = ""

private func setUpServer() async throws {
    let router = Router()
    router.get("bench/status") { _, _ in HTTPResponse.Status.noContent }
    router.get("bench/tiny") { _, _ in "OK" }
    router.get("bench/json") { _, _ in BenchmarkPayload() }
    router.get("bench/large") { _, _ in largePayload }
    router.get("bench/stream") { _, _ in
        Response(
            status: .ok,
            body: .init(contentLength: 16384) { writer in
                for _ in 0..<16 { try await writer.write(ByteBuffer(string: streamChunk)) }
                try await writer.finish(nil)
            })
    }
    let group = MultiThreadedEventLoopGroup.singleton
    let (listening, ready) = AsyncThrowingStream<Int, any Error>.makeStream()
    let application = Application(
        router: router,
        configuration: .init(address: .hostname("127.0.0.1", port: 0)),
        onServerRunning: { channel in
            ready.yield(channel.localAddress!.port!)
            ready.finish()
        },
        eventLoopGroupProvider: .shared(group),
        logger: Logger(label: "performance.hummingbird")
    )
    serverTask = Task {
        do { try await application.run() } catch {
            // A failed launch must release the setup waiter as well as the task.
            ready.finish(throwing: error)
            throw error
        }
    }
    var iterator = listening.makeAsyncIterator()
    guard let port = try await iterator.next() else { throw CancellationError() }
    serverURL = "http://127.0.0.1:\(port)"
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
