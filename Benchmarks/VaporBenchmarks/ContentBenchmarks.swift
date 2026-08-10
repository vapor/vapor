import Benchmark
import NIOCore
import Vapor
import Foundation
import HTTPTypes

func contentBenchmarks() {
    Benchmark("content/decode JSON body small") { benchmark in
        let call = RequestCall(
            .post, "/decode",
            headers: [.contentType: "application/json"],
            body: json(#"{"name":"Vapor"}"#)
        )
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.post("decode") { req -> String in
                try await req.content.decode(SmallPayload.self).name
            }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("content/decode JSON body") { benchmark in
        let call = RequestCall(
            .post, "/decode",
            headers: [.contentType: "application/json"],
            body: json(#"{"id":1,"name":"Widget 1","price":9.99,"tags":["a","b","c"]}"#)
        )
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.post("decode") { req -> String in
                try await req.content.decode(Item.self).name
            }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("content/decode JSON array of 100") { benchmark in
        let encoded = try! JSONEncoder().encode(makeItems(100))
        let call = RequestCall(
            .post, "/decode",
            headers: [.contentType: "application/json"],
            body: ByteBuffer(data: encoded)
        )
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.post("decode") { req -> String in
                try await req.content.decode([Item].self).count.description
            }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("content/decode URL-encoded form") { benchmark in
        let call = RequestCall(
            .post, "/decode",
            headers: [.contentType: "application/x-www-form-urlencoded"],
            body: ByteBuffer(string: "email=vapor%40vapor.codes&password=secret")
        )
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.post("decode") { req -> String in
                try await req.content.decode(Credentials.self).email
            }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("content/decode query string") { benchmark in
        let call = RequestCall(.get, "/search?term=widget&page=2&perPage=50")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("search") { req -> String in
                try req.query.decode(SearchQuery.self).term
            }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("content/read single query parameter") { benchmark in
        let call = RequestCall(.get, "/search?term=widget&page=2&perPage=50")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("search") { req -> String in
                try req.query.get(String.self, at: "term")
            }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("content/JSONEncoder single item") { benchmark in
        let encoder = JSONEncoder()
        let item = makeItem()
        for _ in benchmark.scaledIterations {
            blackHole(try encoder.encode(item))
        }
    }

    Benchmark("content/JSONDecoder single item") { benchmark in
        let decoder = JSONDecoder()
        let data = try! JSONEncoder().encode(makeItem())
        for _ in benchmark.scaledIterations {
            blackHole(try decoder.decode(Item.self, from: data))
        }
    }
}
