import Vapor
import Foundation

public func routes(_ router: Router) throws {
    router.get("ping") { req in
        return "123" as StaticString
    }

    router.get("json") { req in
        return ["foo": "bar"] as [String: String]
    }

    router.get("hello", String.parameter) { req in
        return try req.parameter(String.self)
    }

    router.get("users", User.parameter, "foo") { req in
        return try req.parameter(User.self)
    }

    router.get("search") { req in
        return req.query["q"] ?? "none"
    }

    router.get("client") { req in
        return try req.make(FoundationClient.self).get("http://vapor.codes").map(to: String.self) { res in
            return String(data: res.http.body.data ?? Data(), encoding: .ascii) ?? ""
        }
    }
}

struct User: Parameter, Content {
    let string: String

    static func make(for parameter: String, using container: Container) throws -> EventLoopFuture<User> {
        return Future.map(on: container) {
            return User(string: parameter)
        }
    }

    typealias ResolvedParameter = Future<User>

}
