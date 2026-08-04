import Benchmark
import Vapor
import HTTPTypes

/// The cost of the middleware chain itself, and of the middleware most applications actually run.
///
/// The 0/1/5 passthrough series is designed to be read as a series: the difference between them is
/// the per-layer overhead of `HTTPMiddlewareResponder`, isolated from anything the middleware does.
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

    // A thrown Abort caught and rendered by ErrorMiddleware.
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

    // MARK: The chain in isolation
    //
    // The end-to-end benchmarks above are dominated by request creation and response encoding, so a
    // few passthrough layers round away against them. These drive a pre-built chain directly with a
    // reused request, so the per-layer cost of `HTTPMiddlewareResponder` is readable as the
    // difference between them.

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

    // MARK: Sessions

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

    // Touching the session forces it to be created and a set-cookie to be issued.
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
