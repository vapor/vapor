import Benchmark
import Foundation
import HTTPTypes
import Vapor
import VaporMacros

/// The macro-generated routing path, paired with a hand-written equivalent for each case so the
/// generated wrapper's overhead is readable as a difference rather than an absolute.
func macroRoutingBenchmarks() {
    Benchmark("macro-routing/plain route") { benchmark in
        let call = RequestCall(.get, "/macro/plain")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            try await app.register(collection: BenchmarkController())
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("macro-routing/plain route hand-written") { benchmark in
        let call = RequestCall(.get, "/manual/plain")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("manual", "plain") { _ in "plain" }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("macro-routing/typed path parameter") { benchmark in
        let call = RequestCall(.get, "/macro/items/42")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            try await app.register(collection: BenchmarkController())
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("macro-routing/typed path parameter hand-written") { benchmark in
        let call = RequestCall(.get, "/manual/items/42")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("manual", "items", ":id") { req in
                try req.parameters.require("id", as: Int.self).description
            }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("macro-routing/Content response") { benchmark in
        let call = RequestCall(.get, "/macro/item")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            try await app.register(collection: BenchmarkController())
        }
    } teardown: {
        try await tearDownApplication()
    }

    // `@AuthMiddleware` emits `try req.auth.require(...)` into the generated wrapper, so this is
    // the macro path plus auth resolution.
    Benchmark("macro-routing/authenticated route") { benchmark in
        let call = RequestCall(.get, "/macro/me", headers: [.authorization: "Bearer token"])
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            try await app.register(collection: BenchmarkController())
        }
    } teardown: {
        try await tearDownApplication()
    }

    // The optional form emits `req.auth.get(...)` instead, and must not throw when absent.
    Benchmark("macro-routing/optional auth anonymous") { benchmark in
        let call = RequestCall(.get, "/macro/feed")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            try await app.register(collection: BenchmarkController())
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("macro-routing/four path parameters") { benchmark in
        let call = RequestCall(.post, "/macro/lots/E621E1F8-C36C-495A-93FC-0C247A3E6E5F/7/widget/9")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            try await app.register(collection: BenchmarkController())
        }
    } teardown: {
        try await tearDownApplication()
    }
}

struct BenchmarkAuthMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        if request.headers[.authorization] == "Bearer token" {
            request.auth.login(BenchUser(id: 1, name: "Vapor", email: "vapor@vapor.codes"))
        }
        return try await next.respond(to: request)
    }
}

@Controller
struct BenchmarkController {
    @GET("macro", "plain")
    func plain(req: Request) async throws -> String {
        "plain"
    }

    @GET("macro", "items", Int.self)
    func item(req: Request, id: Int) async throws -> String {
        "item \(id)"
    }

    @GET("macro", "item")
    func contentItem(req: Request) async throws -> Item {
        makeItem()
    }

    @GET("macro", "me")
    @AuthMiddleware(BenchUser.self, BenchmarkAuthMiddleware())
    func me(req: Request, user: BenchUser) async throws -> String {
        user.name
    }

    @GET("macro", "feed")
    @AuthMiddleware(BenchUser.self, BenchmarkAuthMiddleware())
    func feed(req: Request, user: BenchUser?) async throws -> String {
        user?.name ?? "anonymous"
    }

    @POST("macro", "lots", UUID.self, Int.self, String.self, Int.self)
    func lots(req: Request, uuid: UUID, number: Int, text: String, anotherNumber: Int) async throws -> String {
        "\(uuid) \(number) \(text) \(anotherNumber)"
    }
}
