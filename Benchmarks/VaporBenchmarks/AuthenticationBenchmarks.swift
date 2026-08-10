import Benchmark
import Vapor
import HTTPTypes

func authenticationBenchmarks() {
    Benchmark("auth/login") { benchmark in
        let request = Request(application: app)
        let user = BenchUser(id: 1, name: "Vapor", email: "vapor@vapor.codes")
        for _ in benchmark.scaledIterations {
            request.auth.login(user)
        }
        blackHole(request)
    } setup: {
        try await setUpApplication { _ in }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("auth/get") { benchmark in
        let request = Request(application: app)
        request.auth.login(BenchUser(id: 1, name: "Vapor", email: "vapor@vapor.codes"))
        for _ in benchmark.scaledIterations {
            blackHole(request.auth.get(BenchUser.self))
        }
    } setup: {
        try await setUpApplication { _ in }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("auth/get miss") { benchmark in
        let request = Request(application: app)
        for _ in benchmark.scaledIterations {
            blackHole(request.auth.get(BenchUser.self))
        }
    } setup: {
        try await setUpApplication { _ in }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("auth/require") { benchmark in
        let request = Request(application: app)
        request.auth.login(BenchUser(id: 1, name: "Vapor", email: "vapor@vapor.codes"))
        for _ in benchmark.scaledIterations {
            blackHole(try request.auth.require(BenchUser.self))
        }
    } setup: {
        try await setUpApplication { _ in }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("auth/has") { benchmark in
        let request = Request(application: app)
        request.auth.login(BenchUser(id: 1, name: "Vapor", email: "vapor@vapor.codes"))
        for _ in benchmark.scaledIterations {
            blackHole(request.auth.has(BenchUser.self))
        }
    } setup: {
        try await setUpApplication { _ in }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("auth/two types") { benchmark in
        let user = BenchUser(id: 1, name: "Vapor", email: "vapor@vapor.codes")
        let token = BenchToken(value: "secret")
        for _ in benchmark.scaledIterations {
            let request = Request(application: app)
            request.auth.login(user)
            request.auth.login(token)
            blackHole(request.auth.get(BenchUser.self))
            blackHole(request.auth.get(BenchToken.self))
        }
    } setup: {
        try await setUpApplication { _ in }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("auth/logout") { benchmark in
        let request = Request(application: app)
        let user = BenchUser(id: 1, name: "Vapor", email: "vapor@vapor.codes")
        for _ in benchmark.scaledIterations {
            request.auth.login(user)
            request.auth.logout(BenchUser.self)
        }
        blackHole(request)
    } setup: {
        try await setUpApplication { _ in }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("auth/basic authenticator authorized") { benchmark in
        let call = RequestCall(.get, "/protected", headers: [.authorization: "Basic dmFwb3I6c2VjcmV0"])
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.grouped(BenchBasicAuthenticator(), BenchUser.guardMiddleware())
                .get("protected") { try $0.auth.require(BenchUser.self).name }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("auth/basic authenticator unauthorized") { benchmark in
        let call = RequestCall(.get, "/protected")
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.grouped(BenchBasicAuthenticator(), BenchUser.guardMiddleware())
                .get("protected") { try $0.auth.require(BenchUser.self).name }
        }
    } teardown: {
        try await tearDownApplication()
    }

    Benchmark("auth/bearer authenticator authorized") { benchmark in
        let call = RequestCall(.get, "/protected", headers: [.authorization: "Bearer token"])
        for _ in benchmark.scaledIterations {
            blackHole(try await run(call))
        }
    } setup: {
        try await setUpApplication { app in
            app.grouped(BenchBearerAuthenticator(), BenchUser.guardMiddleware())
                .get("protected") { try $0.auth.require(BenchUser.self).name }
        }
    } teardown: {
        try await tearDownApplication()
    }
}
