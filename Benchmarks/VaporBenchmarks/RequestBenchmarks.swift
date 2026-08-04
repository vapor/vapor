import Benchmark
import NIOCore
import Vapor
import HTTPTypes

/// The primitives every request pays for, before any routing or handler work.
func requestBenchmarks() {
    Benchmark("request/create") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Request(application: app))
        }
    } setup: {
        try await setUpApplication { _ in }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("request/create with headers and body") { benchmark in
        let headers: HTTPFields = [
            .contentType: "application/json",
            .accept: "application/json",
            .userAgent: "benchmark",
        ]
        let body = ByteBuffer(string: #"{"id":1,"name":"Widget"}"#)
        for _ in benchmark.scaledIterations {
            blackHole(
                Request(
                    application: app,
                    method: .post,
                    url: "/items",
                    headers: headers,
                    collectedBody: body
                )
            )
        }
    } setup: {
        try await setUpApplication { _ in }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("request/read header") { benchmark in
        let request = Request(application: app, headers: [.contentType: "application/json"])
        for _ in benchmark.scaledIterations {
            blackHole(request.headers[.contentType])
        }
    } setup: {
        try await setUpApplication { _ in }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("request/write header") { benchmark in
        let request = Request(application: app)
        for _ in benchmark.scaledIterations {
            request.headers[.contentType] = "application/json"
        }
        blackHole(request)
    } setup: {
        try await setUpApplication { _ in }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("request/parse URI with query") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URI(string: "https://vapor.codes/api/items?term=widget&page=2&perPage=50"))
        }
    }

    Benchmark("request/parse basic authorization header") { benchmark in
        let headers: HTTPFields = [.authorization: "Basic dmFwb3I6c2VjcmV0"]
        for _ in benchmark.scaledIterations {
            blackHole(headers.basicAuthorization)
        }
    }

    Benchmark("request/parse bearer authorization header") { benchmark in
        let headers: HTTPFields = [.authorization: "Bearer token"]
        for _ in benchmark.scaledIterations {
            blackHole(headers.bearerAuthorization)
        }
    }
}
