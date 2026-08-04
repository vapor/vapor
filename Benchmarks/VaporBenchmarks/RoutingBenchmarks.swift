import Benchmark
import Vapor
import Foundation
import RoutingKit

func routingBenchmarks() {
    // Baseline for everything else here: the cheapest possible route.
    Benchmark("routing/static shallow") { benchmark in
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

    // Four segments rather than one, to expose per-segment trie descent cost.
    Benchmark("routing/static deep") { benchmark in
        let call = RequestCall(.get, "/api/v1/users/list")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("api", "v1", "users", "list") { _ in "hello" }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("routing/one path parameter") { benchmark in
        let call = RequestCall(.get, "/users/42")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("users", ":id") { req in
                try req.parameters.require("id", as: Int.self).description
            }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("routing/three path parameters") { benchmark in
        let call = RequestCall(.get, "/orgs/vapor/repos/vapor/issues/42")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("orgs", ":org", "repos", ":repo", "issues", ":issue") { req in
                let org = try req.parameters.require("org")
                let repo = try req.parameters.require("repo")
                let issue = try req.parameters.require("issue", as: Int.self)
                return "\(org)/\(repo)#\(issue)"
            }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("routing/catchall") { benchmark in
        let call = RequestCall(.get, "/files/images/logo/vapor.png")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("files", "**") { req in
                req.parameters.getCatchall().joined(separator: "/")
            }
        }
    } teardown: {
        try await tearDownApplication()
    }

    // A miss still walks the trie and then builds a 404 through ErrorMiddleware.
    Benchmark("routing/not found") { benchmark in
        let call = RequestCall(.get, "/does/not/exist")
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

    // Routing should be insensitive to how many routes are registered; this is the check.
    Benchmark("routing/hit among 200 routes") { benchmark in
        let call = RequestCall(.get, "/api/resource150/detail")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            for index in 0..<200 {
                app.get("api", "resource\(index)", "detail") { _ in "hello" }
            }
        }
    } teardown: {
        try await tearDownApplication()
    }

    // Method dispatch: same path registered for several verbs.
    Benchmark("routing/method dispatch") { benchmark in
        let call = RequestCall(.patch, "/items/1")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.get("items", ":id") { _ in "get" }
            app.post("items", ":id") { _ in "post" }
            app.put("items", ":id") { _ in "put" }
            app.patch("items", ":id") { _ in "patch" }
            app.delete("items", ":id") { _ in "delete" }
        }
    } teardown: {
        try await tearDownApplication()
    }

    // MARK: Parameter decoding in isolation

    Benchmark("routing/parameters require String") { benchmark in
        var parameters = Parameters()
        parameters.set("id", to: "42")
        for _ in benchmark.scaledIterations {
            blackHole(try parameters.require("id"))
        }
    }

    Benchmark("routing/parameters require Int") { benchmark in
        var parameters = Parameters()
        parameters.set("id", to: "42")
        for _ in benchmark.scaledIterations {
            blackHole(try parameters.require("id", as: Int.self))
        }
    }

    Benchmark("routing/parameters require UUID") { benchmark in
        var parameters = Parameters()
        parameters.set("id", to: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        for _ in benchmark.scaledIterations {
            blackHole(try parameters.require("id", as: UUID.self))
        }
    }
}
