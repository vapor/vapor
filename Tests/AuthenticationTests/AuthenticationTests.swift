import Authentication
import Dispatch
import FluentSQLite
import Vapor
import XCTest

class AuthenticationTests: XCTestCase {
    func testPassword() throws {
        let queue = DispatchEventLoop(label: "test.auth")
        
        let database = SQLiteDatabase(storage: .memory)
        let conn = try database.makeConnection(on: queue).blockingAwait()

        try User.prepare(on: conn).blockingAwait()
        let user = User(name: "Tanner", email: "tanner@vapor.codes", password: "foo")
        try user.save(on: conn).blockingAwait()

        let password = Password(username: "tanner@vapor.codes", password: "foo")
        let authed = try User.authenticate(using: password, verifier: PlaintextVerifier(), on: conn).blockingAwait()
        XCTAssertEqual(authed.id, user.id)
    }

    func testApplication() throws {
//        var services = Services.default()
//        try services.register(FluentProvider())
//        try services.register(AuthenticationProvider())
//
//        let sqlite = SQLiteDatabase(storage: .file(path: "/tmp/auth.sqlite"))
//
//        var databases = DatabaseConfig()
//        databases.add(database: sqlite, as: test)
//        services.register(databases)
//
//        var migrations = MigrationConfig()
//        migrations.add(migration: User.self, database: test)
//        services.register(migrations)
//
//        let app = try Application(services: services)
//
//        let conn = try app.makeConnection(to: test).blockingAwait()
//        let user = User(name: "Tanner", email: "tanner@vapor.codes", password: "foo")
//        try user.save(on: conn).blockingAwait()
//
//        let router = try app.make(Router.self)
//
//        let password = PasswordAuthenticationMiddleware(User.self, verifier: PlaintextVerifier())
//        let group = router.grouped(password)
//        group.get("test") { req -> String in
//            print(req)
//            let user = try req.requireAuthenticated(User.self)
//            print(user)
//            return user.name
//        }
//
//        let req = Request(using: app)
//        req.http.method = .get
//        req.http.uri.path = "test"
//        req.http.headers.basicAuthorization = Password(username: "tanner@vapor.codes", password: "foo")
//
//        let responder = try app.make(Responder.self)
//        let res = try responder.respond(to: req).blockingAwait()
//        XCTAssertEqual(res.http.status, .ok)
//        XCTAssertEqual(res.http.body.data, Data("Tanner".utf8))
    }

    static var allTests = [
        ("testPassword", testPassword),
        ("testApplication", testApplication),
    ]
}
