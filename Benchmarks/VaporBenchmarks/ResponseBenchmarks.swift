import Benchmark
import Foundation
import NIOCore
import Vapor
import HTTPTypes

func responseBenchmarks() {
    Benchmark("response/String") { benchmark in
        let call = RequestCall(.get, "/string")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("string") { _ in "hello" }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("response/HTTPResponse.Status") { benchmark in
        let call = RequestCall(.get, "/status")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("status") { _ in HTTPResponse.Status.noContent }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("response/Response constructed directly") { benchmark in
        let call = RequestCall(.get, "/response")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("response") { _ in
                Response(status: .created, headers: [.contentType: "text/plain"], body: .init(string: "hello"))
            }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("response/Content small") { benchmark in
        let call = RequestCall(.get, "/small")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("small") { _ in SmallPayload(name: "Vapor") }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("response/Content single") { benchmark in
        let call = RequestCall(.get, "/item")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            let item = makeItem()
            app.get("item") { _ in item }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("response/Content array of 10") { benchmark in
        let call = RequestCall(.get, "/items")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            let items = makeItems(10)
            app.get("items") { _ in items }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("response/Content array of 100") { benchmark in
        let call = RequestCall(.get, "/items")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            let items = makeItems(100)
            app.get("items") { _ in items }
        }
    } teardown: {
        try await tearDownApplication()
    }

    // Uses `Data` rather than `ByteBuffer` so the benchmark keeps working as NIO types are
    // removed from `Response.Body`'s public API, and stays comparable across those changes.
    Benchmark("response/binary body 1KiB") { benchmark in
        let call = RequestCall(.get, "/buffer")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            let payload = Data(String(repeating: "x", count: 1024).utf8)
            app.get("buffer") { _ in Response(body: .init(data: payload)) }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("response/redirect") { benchmark in
        let call = RequestCall(.get, "/redirect")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("redirect") { $0.redirect(to: "/elsewhere") }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("response/encode Content directly") { benchmark in
        let request = Request(application: app)
        let item = makeItem()
        for _ in benchmark.scaledIterations {
            blackHole(try await item.encodeResponse(for: request))
        }
    } setup: {
        try await setUpApplication { _ in }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("response/encode String directly") { benchmark in
        let request = Request(application: app)
        for _ in benchmark.scaledIterations {
            blackHole(try await "hello".encodeResponse(for: request))
        }
    } setup: {
        try await setUpApplication { _ in }
    } teardown: {
        try await tearDownApplication()
    }
}
