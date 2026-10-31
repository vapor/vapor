import Benchmark
import Foundation
import HTTPTypes
import RoutingKit
@_spi(Benchmarking) import Vapor

func routingBenchmarks() {
    // Keep construction costs visible when trading startup storage for fast lookup.
    for count in [200, 1000] {
        Benchmark("routing.build-\(count)-static-routes", configuration: .init(scalingFactor: .one)) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(app.makeBenchmarkResponder())
            }
        } setup: {
            try await setUpApplication { app in
                for index in 0..<count {
                    app.get("api", "resource\(index)", "detail") { _ in "hello" }
                }
            }
        } teardown: {
            try await tearDownApplication()
        }
    }

    for (name, method, path) in [
        ("literal-with-dynamic-neighbours", HTTPRequest.Method.get, "/items/fixed"),
        ("parameter-with-literal-neighbours", .get, "/items/123"),
        ("encoded-literal", .get, "/items/f%69xed"),
        ("trailing-slash-literal", .get, "/items/fixed/"),
        ("HEAD-parameter-before-GET-literal", .head, "/items/fixed"),
    ] {
        Benchmark("routing.\(name)") { benchmark in
            let call = RequestCall(method, path)
            for _ in benchmark.scaledIterations { blackHole(try await run(call)) }
        } setup: {
            try await setUpApplication { app in
                app.get("items", "fixed") { _ in "literal" }
                app.get("items", ":id") { request in try request.parameters.require("id") }
                app.on(.head, "items", ":id") { _ in "explicit HEAD" }
            }
        } teardown: {
            try await tearDownApplication()
        }
    }

    Benchmark("routing.case-insensitive-literal") { benchmark in
        let call = RequestCall(.get, "/API/HeLLo")
        for _ in benchmark.scaledIterations { blackHole(try await run(call)) }
    } setup: {
        try await setUpApplication { app in
            app.routes.caseInsensitive = true
            app.get("api", "hello") { _ in "hello" }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("routing.static-shallow") { benchmark in
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

    Benchmark("routing.static-deep") { benchmark in
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

    Benchmark("routing.one-path-parameter") { benchmark in
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

    Benchmark("routing.three-path-parameters") { benchmark in
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

    Benchmark("routing.catchall") { benchmark in
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

    Benchmark("routing.not-found") { benchmark in
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

    Benchmark("routing.hit-among-200-routes") { benchmark in
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

    Benchmark("routing.method-dispatch") { benchmark in
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

    Benchmark("routing.parameters-require-String") { benchmark in
        var parameters = Parameters()
        parameters.set("id", to: "42")
        for _ in benchmark.scaledIterations {
            blackHole(try parameters.require("id"))
        }
    }

    Benchmark("routing.parameters-require-Int") { benchmark in
        var parameters = Parameters()
        parameters.set("id", to: "42")
        for _ in benchmark.scaledIterations {
            blackHole(try parameters.require("id", as: Int.self))
        }
    }

    Benchmark("routing.parameters-require-UUID") { benchmark in
        var parameters = Parameters()
        parameters.set("id", to: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        for _ in benchmark.scaledIterations {
            blackHole(try parameters.require("id", as: UUID.self))
        }
    }
}
