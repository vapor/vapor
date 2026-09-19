import AsyncHTTPClient
import Benchmark
import BenchmarkSupport
import Foundation
import HTTPTypes
import Logging
import Vapor

private struct BenchmarkPayload: Content {
    var id = 1
    var name = "benchmark"
    var tags = ["a", "b", "c"]
}

private let largePayload = String(repeating: "x", count: 65536)
private let streamChunk = String(repeating: "y", count: 1024)
nonisolated(unsafe) private var serverTask: Task<Void, any Error>?
nonisolated(unsafe) private var serverURL = ""

private func configureWorkloads(_ app: Application) {
    app.get("bench", "status") { _ in HTTPResponse.Status.noContent }
    app.get("bench", "tiny") { _ in "OK" }
    app.get("bench", "json") { _ in BenchmarkPayload() }
    app.get("bench", "large") { _ in largePayload }
    app.get("bench", "stream") { _ in
        Response(
            body: try .init(
                stream: { writer in
                    for _ in 0..<16 { try await writer.write(streamChunk) }
                }, count: 16384))
    }
    for reads in [1, 10] {
        app.get("bench", "id-\(reads)") { request in
            var value = ""
            for _ in 0..<reads { value += request.id }
            return value
        }
    }
    app.on(.post, "bench", "discard", maxBodySize: "1mb") { _ in
        HTTPResponse.Status.noContent
    }
    app.on(.post, "bench", "echo", maxBodySize: "1mb") { request in
        let data = try await request.body.collect() ?? Data()
        return Response(body: .init(data: data), contentConfiguration: benchmarkContentConfiguration)
    }
}

func endToEndBenchmarks() {
    for route in ["status", "tiny", "json", "large", "stream"] {
        // Includes request construction, routing, middleware, encoding, and body consumption.
        // Mirrors Hummingbird's responder benchmarks, while retaining the cost of copying bytes.
        Benchmark("e2e/\(route)") { benchmark in
            let call = RequestCall(.get, "/bench/\(route)")
            for _ in benchmark.scaledIterations { blackHole(try await run(call)) }
        } setup: {
            try await setUpApplication { configureWorkloads($0) }
        } teardown: {
            try await tearDownApplication()
        }

        // Actual HTTP framing and socket transport. Counters include the in-process AHC client:
        // use this to compare revisions, not as a server-only allocation count.
        Benchmark("network/\(route)", configuration: .init(scalingFactor: .one)) { benchmark in
            let request = HTTPClientRequest(url: serverURL + "/bench/\(route)")
            for _ in benchmark.scaledIterations {
                let response = try await HTTPClient.shared.execute(request, timeout: .seconds(5))
                let body = try await response.body.collect(upTo: 131072)
                precondition(Int(response.status.code) == (route == "status" ? 204 : 200))
                blackHole(body)
            }
        } setup: {
            try await setUpApplication { app in
                configureWorkloads(app)
                app.serverConfiguration.hostname = "127.0.0.1"
                app.serverConfiguration.port = 0
            }
            let server = app.server
            serverTask = Task { try await server.run() }
            let address = try await server.listeningAddress
            serverURL = "http://127.0.0.1:\(address.port!)"
            try await validateResponse(route: route, at: serverURL)
        } teardown: {
            serverTask?.cancel()
            _ = await serverTask?.result
            serverTask = nil
            try await tearDownApplication()
        }
    }

    // Separate from the established network suite: the handler leaves the upload
    // unread, exercising bounded server draining and keep-alive after the response.
    for bodySize in [1024, 65536] {
        Benchmark("drain-network/\(bodySize / 1024)KiB", configuration: .init(scalingFactor: .one)) { benchmark in
            var request = HTTPClientRequest(url: serverURL + "/bench/discard")
            request.method = .POST
            request.body = .bytes([UInt8](repeating: 120, count: bodySize))
            for _ in benchmark.scaledIterations {
                let response = try await HTTPClient.shared.execute(request, timeout: .seconds(5))
                let body = try await response.body.collect(upTo: 131072)
                precondition(response.status.code == 204)
                precondition(body.readableBytes == 0)
                blackHole(body)
            }
        } setup: {
            try await setUpApplication { app in
                configureWorkloads(app)
                app.serverConfiguration.hostname = "127.0.0.1"
                app.serverConfiguration.port = 0
                app.serverConfiguration.maxDrainBytes = 1 << 20
            }
            let server = app.server
            serverTask = Task { try await server.run() }
            let address = try await server.listeningAddress
            serverURL = "http://127.0.0.1:\(address.port!)"
        } teardown: {
            serverTask?.cancel()
            _ = await serverTask?.result
            serverTask = nil
            try await tearDownApplication()
        }
    }

    // Exercise actual transport ID access and request-body ownership, in addition to empty GETs.
    for (name, route, bodySize) in [
        ("id-once", "id-1", 0), ("id-repeated", "id-10", 0),
        ("echo-1KiB", "echo", 1024), ("echo-64KiB", "echo", 65536),
    ] {
        Benchmark("network/\(name)", configuration: .init(scalingFactor: .one)) { benchmark in
            var request = HTTPClientRequest(url: serverURL + "/bench/\(route)")
            if bodySize > 0 {
                request.method = .POST
                request.body = .bytes([UInt8](repeating: 120, count: bodySize))
            }
            for _ in benchmark.scaledIterations {
                let response = try await HTTPClient.shared.execute(request, timeout: .seconds(5))
                let body = try await response.body.collect(upTo: 131072)
                precondition(response.status.code == 200)
                if bodySize > 0 { precondition(body.readableBytes == bodySize) }
                blackHole(body)
            }
        } setup: {
            try await setUpApplication { app in
                configureWorkloads(app)
                app.serverConfiguration.hostname = "127.0.0.1"
                app.serverConfiguration.port = 0
            }
            let server = app.server
            serverTask = Task { try await server.run() }
            let address = try await server.listeningAddress
            serverURL = "http://127.0.0.1:\(address.port!)"
        } teardown: {
            serverTask?.cancel()
            _ = await serverTask?.result
            serverTask = nil
            try await tearDownApplication()
        }
    }
}
