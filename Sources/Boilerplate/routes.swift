import Vapor

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

    router.get("search") { req in
        return req.query["q"] ?? "none"
    }

    router.get("client") { req in
        return try req.client().get("http://vapor.codes").map { $0.description }
    }
}
