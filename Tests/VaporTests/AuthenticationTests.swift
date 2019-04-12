import XCTVapor

final class AuthenticationTests: XCTestCase {
    func testBearerAuthenticator() throws {
        struct Foo: Authenticatable {
            var name: String
        }

        struct FooAuthenticator: BearerAuthenticator {
            typealias User = Foo

            func authenticate(bearer: BearerAuthorization) -> EventLoopFuture<Foo?> {
                guard bearer.token == "foo" else {
                    return EmbeddedEventLoop().makeSucceededFuture(nil)
                }
                let foo = Foo(name: "Vapor")
                return EmbeddedEventLoop().makeSucceededFuture(foo)
            }
        }

        let app = Application.create(routes: { r, c in
            r.grouped([
                FooAuthenticator().middleware(), Foo.guardMiddleware()
            ]).get("foo") { req -> String in
                return try req.requireAuthenticated(Foo.self).name
            }
        })
        defer { app.shutdown() }

        try app.testable().inMemory()
            .test(.GET, "foo") { res in
                XCTAssertEqual(res.status, .unauthorized)
            }
            .test(.GET, "foo", headers: ["Authorization": "Bearer foo"]) { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, "Vapor")
            }
    }
//    func testPassword() throws {
//        let queue = MultiThreadedEventLoopGroup(numberOfThreads: 1)
//
//        let database = try SQLiteDatabase(storage: .memory)
//        let conn = try database.newConnection(on: queue).wait()
//
//        try User.prepare(on: conn).wait()
//        let user = User(name: "Tanner", email: "tanner@vapor.codes", password: "foo")
//        _ = try user.save(on: conn).wait()
//        let password = BasicAuthorization(username: "tanner@vapor.codes", password: "foo")
//        let authed = try User.authenticate(using: password, verifier: PlaintextVerifier(), on: conn).wait()
//        XCTAssertEqual(authed?.id, user.id)
//    }
//
//    func testApplication() throws {
//        var services = Services.default()
//        try services.register(FluentProvider())
//        try services.register(FluentSQLiteProvider())
//        try services.register(AuthenticationProvider())
//
//        let sqlite = try SQLiteDatabase(storage: .memory)
//        var databases = DatabasesConfig()
//        databases.add(database: sqlite, as: .test)
//        services.register(databases)
//
//        var migrations = MigrationConfig()
//        migrations.add(model: User.self, database: .test)
//        services.register(migrations)
//
//        let app = try Application(services: services)
//
//        let conn = try app.newConnection(to: .test).wait()
//        defer { conn.close() }
//
//        let user = User(name: "Tanner", email: "tanner@vapor.codes", password: "foo")
//        _ = try user.save(on: conn).wait()
//        let router = try app.make(Router.self)
//
//        let password = User.basicAuthMiddleware(using: PlaintextVerifier())
//        let group = router.grouped(password)
//        group.get("test") { req -> String in
//            let user = try req.requireAuthenticated(User.self)
//            return user.name
//        }
//
//        let req = Request(using: app)
//        req.http.method = .GET
//        req.http.urlString = "/test"
//        req.http.headers.basicAuthorization = .init(username: "tanner@vapor.codes", password: "foo")
//
//        let responder = try app.make(Responder.self)
//        let res = try responder.respond(to: req).wait()
//        XCTAssertEqual(res.http.status, .ok)
//        try XCTAssertEqual(res.http.body.consumeData(max: 100, on: app).wait(), Data("Tanner".utf8))
//    }
//
//    func testSessionPersist() throws {
//        var services = Services.default()
//        try services.register(FluentSQLiteProvider())
//        try services.register(AuthenticationProvider())
//
//        let sqlite = try SQLiteDatabase(storage: .memory)
//        var databases = DatabasesConfig()
//        databases.add(database: sqlite, as: .test)
//        services.register(databases)
//
//        var migrations = MigrationConfig()
//        migrations.add(model: User.self, database: .test)
//        migrations.prepareCache(for: .test)
//        services.register(migrations)
//
//        var middleware = MiddlewareConfig.default()
//        middleware.use(SessionsMiddleware.self)
//        services.register(middleware)
//
//        services.register(KeyedCache.self) { container -> SQLiteCache in
//            let pool = try container.connectionPool(to: .test)
//            return .init(pool: pool)
//        }
//
//        var config = Config.default()
//        config.prefer(SQLiteCache.self, for: KeyedCache.self)
//
//        let app = try Application(config: config, services: services)
//
//        let conn = try app.newConnection(to: .test).wait()
//        defer { conn.close() }
//
//        let user = User(name: "Tanner", email: "tanner@vapor.codes", password: "foo")
//        _ = try user.save(on: conn).wait()
//
//        let router = try app.make(Router.self)
//
//        let group = router.grouped(
//            User.authSessionsMiddleware(),
//            User.basicAuthMiddleware(using: PlaintextVerifier()),
//            User.guardAuthMiddleware()
//        )
//        group.get("test") { req -> String in
//            let user = try req.requireAuthenticated(User.self)
//            return user.name
//        }
//
//        group.get("logout") { req -> HTTPStatus in
//            try req.destroySession()
//            try req.unauthenticate(User.self)
//            return .ok
//        }
//
//        let responder = try app.make(Responder.self)
//
//        /// non-authed req
//        do {
//            let req = Request(using: app)
//            req.http.method = .GET
//            req.http.urlString = "/test"
//
//            let res = try responder.respond(to: req).wait()
//            XCTAssertEqual(res.http.status, .unauthorized)
//        }
//
//        /// authed req
//        let session: String
//        do {
//            let req = Request(using: app)
//            req.http.method = .GET
//            req.http.urlString = "/test"
//            req.http.headers.basicAuthorization = .init(username: "tanner@vapor.codes", password: "foo")
//
//            let res = try responder.respond(to: req).wait()
//            XCTAssertEqual(res.http.status, .ok)
//            try XCTAssertEqual(res.http.body.consumeData(max: 100, on: app).wait(), Data("Tanner".utf8))
//            session = res.http.headers[.setCookie].first?.split(separator: ";").first.flatMap(String.init) ?? "n/a"
//        }
//
//        /// persisted req
//        do {
//            let req = Request(using: app)
//            req.http.method = .GET
//            req.http.urlString = "/test"
//            req.http.headers.replaceOrAdd(name: .cookie, value: session)
//
//
//            let res = try responder.respond(to: req).wait()
//            XCTAssertEqual(res.http.status, .ok)
//            try XCTAssertEqual(res.http.body.consumeData(max: 100, on: app).wait(), Data("Tanner".utf8))
//        }
//
//        /// persisted, no-session req
//        do {
//            let req = Request(using: app)
//            req.http.method = .GET
//            req.http.urlString = "/test"
//
//            let res = try responder.respond(to: req).wait()
//            XCTAssertEqual(res.http.status, .unauthorized)
//        }
//
//        /// logout req
//        do {
//            let req = Request(using: app)
//            req.http.method = .GET
//            req.http.urlString = "/logout"
//            req.http.headers.replaceOrAdd(name: .cookie, value: session)
//
//            let res = try responder.respond(to: req).wait()
//            XCTAssertEqual(res.http.status, .ok)
//        }
//
//        // ensure the session has been removed from storage
//        do {
//            let conn = try sqlite.newConnection(on: app.eventLoop).wait()
//            try conn.raw("SELECT COUNT(*) as count FROM fluentcache").run { row in
//                let count = row.firstValue(forColumn: "count")!.description
//                XCTAssertEqual(count, "0")
//            }.wait()
//        }
//
//        /// logged-out persisted req
//        do {
//            let req = Request(using: app)
//            req.http.method = .GET
//            req.http.urlString = "/test"
//            req.http.headers.replaceOrAdd(name: .cookie, value: session)
//
//            let res = try responder.respond(to: req).wait()
//            XCTAssertEqual(res.http.status, .unauthorized)
//        }
//    }
}
