import Vapor
import Foundation

public func routes(_ router: Router) throws {
    router.get("ping") { req in
        return "123" as StaticString
    }

    router.get("json") { req in
        return ["foo": "bar"]
    }

    router.get("hello", String.parameter) { req in
        return try req.parameters.next(String.self)
    }

    router.get("users", User.parameter, "foo") { req in
        return try req.parameters.next(User.self)
    }

    router.get("search") { req in
        return req.query["q"] ?? "none"
    }

    router.get("client") { req in
        return try req.make(FoundationClient.self).get("http://vapor.codes").map { res in
            return String(data: res.http.body.data ?? Data(), encoding: .ascii) ?? ""
        }
    }
}

struct User: Parameter, Content {
    let string: String
    static func resolveParameter(_ parameter: String, on container: Container) throws -> Future<User> {
        return container.eventLoop.newSucceededFuture(result: User(string: parameter))
    }
}
