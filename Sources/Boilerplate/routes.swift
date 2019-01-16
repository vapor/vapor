import Vapor

public func routes(_ r: HTTPRoutes, _ c: Container) throws {
    r.get("ping") { req -> StaticString in
        return "123"
    }
    
    r.post("login") { req -> String in
        struct Creds: Codable {
            var email: String
            var password: String
        }
        
        let creds = try req.content.decode(Creds.self)
        return "\(creds)"
    }

    r.get("json") { req in
        return ["foo": "bar"]
    }

//    r.get("hello", String.parameter) { req in
//        return try req.parameters.next(String.self)
//    }
//
//    router.get("search") { req in
//        return req.query["q"] ?? "none"
//    }
//
//    let sessions = router.grouped("sessions").grouped(SessionsMiddleware.self)
//    sessions.get("get") { req -> String in
//        return try req.session()["name"] ?? "n/a"
//    }
//    sessions.get("set", String.parameter) { req -> String in
//        let name = try req.parameters.next(String.self)
//        try req.session()["name"] = name
//        return name
//    }
//    sessions.get("del") { req -> String in
//        try req.destroySession()
//        return "done"
//    }
//
//    r.get("client") { req in
//        return try c.client().get("http://vapor.codes").map { $0.description }
//    }
    
    let users = r.grouped("users")
    users.get { req in
        return "users"
    }
    users.get(.parameter("userID")) { req in
        return "user"
    }
}
