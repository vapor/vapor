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

    let sessions = router.grouped("sessions").grouped(SessionsMiddleware.self)
    sessions.get("get") { req -> String in
        return try req.session()["name"] ?? "n/a"
    }
    sessions.get("set", String.parameter) { req -> String in
        let name = try req.parameters.next(String.self)
        try req.session()["name"] = name
        return name
    }
    sessions.get("del") { req -> String in
        try req.destroySession()
        return "done"
    }

    router.get("client") { req in
        return try req.client().get("http://vapor.codes").map { $0.description }
    }
}
