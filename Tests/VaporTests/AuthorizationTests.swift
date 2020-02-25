import XCTVapor

final class AuthorizationTests: XCTestCase {
    func testRoleAuthorization() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.routes.grouped([
            TestUser.authenticator,
            TestUser.authorizer(role: .admin)
        ]).get("test") { req -> String in
            try XCTAssertEqual(req.authz.require(TestUser.Role.self), .admin)
            return try req.authc.require(TestUser.self).name
        }

        try app.test(.GET, "/test", afterResponse: { res in
            XCTAssertEqual(res.status, .unauthorized)
        }).test(.GET, "/test", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: "admin")
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Vapor")
        }).test(.GET, "/test", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: "user")
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .forbidden)
        })
    }

    func testParameterAuthorization() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.routes.grouped([
            EvenParameterAuthorizer(name: "foo")
        ]).get("test", ":foo") { req -> HTTPStatus in
            .ok
        }

        try app.test(.GET, "/test/1", afterResponse: { res in
            XCTAssertEqual(res.status, .forbidden)
        }).test(.GET, "/test/2", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
        })
    }
}

private enum TestRole: Equatable, Authorizable {
    case user
    case admin
}

private struct TestUser: RoleAuthorizable {
    static var authenticator: TestAuthenticator {
        .init()
    }

    var name: String
    var role: TestRole
}

private struct TestAuthenticator: BearerAuthenticator {
    typealias User = TestUser

    func authenticate(
        bearer: BearerAuthorization,
        for request: Request
    ) -> EventLoopFuture<TestUser?> {
        let role: User.Role
        switch bearer.token {
        case "user":
            role = .user
        case "admin":
            role = .admin
        default:
            return request.eventLoop.makeSucceededFuture(nil)
        }
        let test = TestUser(name: "Vapor", role: role)
        return request.eventLoop.makeSucceededFuture(test)
    }
}

private struct EvenParameterAuthorizer: ParameterAuthorizer {
    var name: String
    func authorize(parameter: Int, for request: Request) -> EventLoopFuture<Void> {
        guard parameter % 2 == 0 else {
            return request.eventLoop.makeFailedFuture(Abort(.forbidden))
        }
        return request.eventLoop.makeSucceededFuture(())
    }
}
