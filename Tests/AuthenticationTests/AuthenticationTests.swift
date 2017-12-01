import Authentication
import FluentSQLite
import XCTest

class AuthenticationTests: XCTestCase {
    func testPassword() throws {
        let queue = DispatchQueue(label: "test.auth")
        let database = SQLiteDatabase(storage: .memory)
        let conn = try database.makeConnection(on: queue).blockingAwait()

        try User.prepare(on: conn).blockingAwait()
        let user = User(name: "Tanner", email: "tanner@vapor.codes", password: "foo")
        try user.save(on: conn).blockingAwait()

        let password = Password(username: "tanner@vapor.codes", password: "foo")
        let authed = try User.authenticate(using: password, verifier: PlaintextVerifier(), on: conn).blockingAwait()
        XCTAssertEqual(authed.id, user.id)
    }

    static var allTests = [
        ("testPassword", testPassword),
    ]
}
