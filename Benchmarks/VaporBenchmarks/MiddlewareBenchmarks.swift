import Benchmark
import Vapor
import HTTPTypes

func middlewareBenchmarks() {
    Benchmark("middleware/none") { benchmark in
        let call = RequestCall(.get, "/hello")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("hello") { _ in "hello" }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("middleware/one passthrough") { benchmark in
        let call = RequestCall(.get, "/hello")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.grouped(PassthroughMiddleware()).get("hello") { _ in "hello" }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("middleware/five passthrough") { benchmark in
        let call = RequestCall(.get, "/hello")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.grouped([any Middleware](repeating: PassthroughMiddleware(), count: 5))
                .get("hello") { _ in "hello" }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("middleware/error handling") { benchmark in
        let call = RequestCall(.get, "/boom")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("boom") { _ -> String in throw Abort(.badRequest, reason: "nope") }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("middleware/CORS") { benchmark in
        let call = RequestCall(.get, "/hello", headers: [.origin: "https://vapor.codes"])
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.grouped(CORSMiddleware()).get("hello") { _ in "hello" }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("middleware/CORS preflight") { benchmark in
        let call = RequestCall(
            .options, "/hello",
            headers: [
                .origin: "https://vapor.codes",
                .accessControlRequestMethod: "GET",
            ]
        )
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.grouped(CORSMiddleware()).get("hello") { _ in "hello" }
        }
    } teardown: {
        try await tearDownApplication()
    }

    for count in [0, 1, 5, 20] {
        Benchmark("middleware/chain \(count) layers") { benchmark in
            let request = Request(application: app)
            let chain = [any Middleware](repeating: PassthroughMiddleware(), count: count)
                .makeResponder(chainingTo: EchoResponder())
            for _ in benchmark.scaledIterations {
                blackHole(try await chain.respond(to: request))
            }
        } setup: {
            try await setUpApplication { _ in }
        } teardown: {
            try await tearDownApplication()
        }
    }

    Benchmark("middleware/sessions no cookie") { benchmark in
        let call = RequestCall(.get, "/hello")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.grouped(app.sessions.middleware).get("hello") { _ in "hello" }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("middleware/sessions write") { benchmark in
        let call = RequestCall(.get, "/hello")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.grouped(app.sessions.middleware).get("hello") { req -> String in
                req.session.data["visits"] = "1"
                return "hello"
            }
        }
    } teardown: {
        try await tearDownApplication()
    }
}
