import Benchmark
import Foundation
import HTTPTypes
import NIOCore
import Vapor

func requestBenchmarks() {
    Benchmark("request.parse-cookies") { benchmark in
        let headers: HTTPFields = [.cookie: "session=abc123; theme=dark; language=en"]
        precondition(headers.cookie?["session"]?.string == "abc123")
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(headers.cookie)
        }
    }

    for reads in [0, 1, 10] {
        Benchmark("request.create-configured-and-read-ID-\(reads)-times") { benchmark in
            for _ in benchmark.scaledIterations {
                let request = Request(contentConfiguration: benchmarkContentConfiguration)
                for _ in 0..<reads { blackHole(request.id) }
                blackHole(request)
            }
        }
    }

    for (name, path) in [("plain", "/bench/tiny"), ("escaped-with-query", "/items/hello%20world?q=a%2Fb")] {
        Benchmark("request.origin-path-\(name)") { benchmark in
            for _ in benchmark.scaledIterations {
                let uri = URI(path: path)
                blackHole(uri.path)
                blackHole(uri.query)
            }
        }
    }

    Benchmark("request.mutate-origin-path") { benchmark in
        for _ in benchmark.scaledIterations {
            var uri = URI(path: "/items/one?sort=name")
            uri.query = "sort=date"
            uri.path = "/items/two"
            blackHole(uri.string)
        }
    }

    Benchmark("request.create") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Request())
        }
    } setup: {
        try await setUpApplication { _ in }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("request.create-with-headers-and-body") { benchmark in
        let headers: HTTPFields = [
            .contentType: "application/json",
            .accept: "application/json",
            .userAgent: "benchmark",
        ]
        let body = json(#"{"id":1,"name":"Widget"}"#)
        for _ in benchmark.scaledIterations {
            blackHole(
                Request(
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

    Benchmark("request.read-header") { benchmark in
        let request = Request(headers: [.contentType: "application/json"])
        for _ in benchmark.scaledIterations {
            blackHole(request.headers[.contentType])
        }
    } setup: {
        try await setUpApplication { _ in }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("request.write-header") { benchmark in
        var request = Request()
        for _ in benchmark.scaledIterations {
            request.headers[.contentType] = "application/json"
        }
        blackHole(request)
    } setup: {
        try await setUpApplication { _ in }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("request.parse-URI-with-query") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URI(string: "https://vapor.codes/api/items?term=widget&page=2&perPage=50"))
        }
    }

    Benchmark("request.parse-basic-authorization-header") { benchmark in
        let headers: HTTPFields = [.authorization: "Basic dmFwb3I6c2VjcmV0"]
        for _ in benchmark.scaledIterations {
            blackHole(headers.basicAuthorization)
        }
    }

    Benchmark("request.parse-bearer-authorization-header") { benchmark in
        let headers: HTTPFields = [.authorization: "Bearer token"]
        for _ in benchmark.scaledIterations {
            blackHole(headers.bearerAuthorization)
        }
    }
}
