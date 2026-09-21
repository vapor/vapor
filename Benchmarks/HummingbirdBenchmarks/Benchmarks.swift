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
private let smallPayload = String(repeating: "x", count: 1024)
nonisolated(unsafe) private var serverTask: Task<Void, any Error>?
nonisolated(unsafe) private var serverURL = ""

private func setUpServer() async throws {
    let router = Router()
    router.get("bench/status") { _, _ in HTTPResponse.Status.noContent }
    router.get("bench/tiny") { _, _ in "OK" }
    router.get("bench/small") { _, _ in smallPayload }
    router.get("bench/json") { _, _ in BenchmarkPayload() }
    router.get("bench/large") { _, _ in largePayload }
    for workload in responseStreams {
        let chunk = String(repeating: "y", count: workload.chunkSize)
        router.get(.init("bench/\(workload.route)")) { _, _ in
            Response(
                status: .ok,
                body: .init(contentLength: workload.knownLength ? workload.chunkSize * workload.chunkCount : nil) { writer in
                    for _ in 0..<workload.chunkCount { try await writer.write(ByteBuffer(string: chunk)) }
                    try await writer.finish(nil)
                })
        }
    }
    for route in uploadRoutes {
        router.post(.init("bench/\(route)")) { request, _ in
            if route.hasPrefix("collect-") {
                let body = try await request.body.collect(upTo: 131072)
                return Response(status: .ok, body: .init(byteBuffer: body))
            }
            return Response(status: .ok, body: .init(asyncSequence: request.body))
        }
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
    for route in responseRoutes + uploadRoutes {
        // Match Vapor's network fixture, including client, collection bound,
        // timed validation and scaling. Startup and shutdown stay outside timing.
        Benchmark("network/\(route)", configuration: .init(scalingFactor: .one)) { benchmark in
            for _ in benchmark.scaledIterations {
                let request = makeNetworkRequest(route: route, at: serverURL)
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
