import Benchmark
import HTTPTypes
import Vapor

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
            let request = Request()
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
            app.grouped(SessionsMiddleware(session: app.sessionDriver)).get("hello") { _ in "hello" }
        }
    } teardown: {
        try await tearDownApplication()
    }

    // One request per sample lets us remove its session after measurement, including warmups.
    Benchmark("middleware/sessions create", configuration: .init(scalingFactor: .one)) { benchmark in
        let request = Request(url: "/hello", contentConfiguration: benchmarkContentConfiguration)
        let response = try await responder.respond(to: request)
        var bytes = [UInt8]()
        bytes.reserveCapacity(max(0, response.body.count ?? 0))
        try await response.body.withStreamingBytes { span in
            span.withUnsafeBytes { unsafe bytes.append(contentsOf: $0) }
        }
        blackHole(bytes)
        benchmark.stopMeasurement()

        precondition(response.status == .ok && bytes.elementsEqual("hello".utf8))
        guard let cookie = response.cookies["vapor-session"] else {
            preconditionFailure("Session creation must return a session cookie.")
        }
        let id = SessionID(string: cookie.string)
        let stored = try await app.sessionDriver.readSession(id, for: request)
        precondition(stored?["visits"] == "1")
        try await app.sessionDriver.deleteSession(id, for: request)
        let deleted = try await app.sessionDriver.readSession(id, for: request)
        precondition(deleted == nil, "Created sessions must not accumulate between samples.")
    } setup: {
        try await setUpApplication { app in
            app.grouped(SessionsMiddleware(session: app.sessionDriver)).get("hello") { req -> String in
                req.session.data["visits"] = "1"
                return "hello"
            }
        }
    } teardown: {
        try await tearDownApplication()
    }

    let sessionID = SessionID(string: "benchmark-session")
    let sessionHeaders: HTTPFields = [.cookie: "vapor-session=\(sessionID.string)"]
    Benchmark("middleware/sessions update") { benchmark in
        let call = RequestCall(.get, "/hello", headers: sessionHeaders)
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        let storage = MemorySessions.Storage()
        await storage.set(sessionID, to: ["visits": "0"])
        try await setUpApplication { app in
            app.grouped(SessionsMiddleware(session: MemorySessions(storage: storage))).get("hello") { req -> String in
                req.session.data["visits"] = "1"
                return "hello"
            }
        }

        // Confirm that the cookie selects the existing entry and that the handler updates it.
        let request = Request(url: "/hello", headers: sessionHeaders, contentConfiguration: benchmarkContentConfiguration)
        var response = try await responder.respond(to: request)
        let body = try await response.body.collect()
        precondition(response.status == .ok && body.map { $0.elementsEqual("hello".utf8) } == true)
        precondition(response.cookies["vapor-session"]?.string == sessionID.string)
        let stored = await storage.get(sessionID)
        precondition(stored?["visits"] == "1")
    } teardown: {
        try await tearDownApplication()
    }
}
