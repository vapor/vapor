import Vapor

struct Creds: Content {
    var email: String
    var password: String
}

public func routes(_ r: Routes, _ c: Container) throws {
    r.on(.GET, "ping", body: .stream) { req in
        return "123" as StaticString
    }
    
    r.post("login") { req -> String in
        let creds = try req.content.decode(Creds.self)
        return "\(creds)"
    }
    
    r.on(.POST, "large-file", body: .collect(maxSize: 1_000_000_000)) { req -> String in
        return req.body.data?.readableBytes.description  ?? "none"
    }

    r.get("json") { req -> [String: String] in
        return ["foo": "bar"]
    }.description("returns some test json")
    
    r.webSocket("ws") { req, ws in
        ws.onText { ws, text in
            ws.send(text: text.reversed())
        }
        
        let ip = req.channel.remoteAddress?.description ?? "<no ip>"
        ws.send(text: "Hello 👋 \(ip)")
    }
    
    r.on(.POST, "file", body: .stream) { req -> EventLoopFuture<String> in
        let promise = req.eventLoop.makePromise(of: String.self)
        req.body.drain { result in
            switch result {
            case .buffer(let buffer):
                debugPrint(buffer)
            case .error(let error):
                promise.fail(error)
            case .end:
                promise.succeed("Done")
            }
        }
        return promise.futureResult
    }
    
    r.get("shutdown") { req -> HTTPStatus in
        guard let running = try c.make(Application.self).running else {
            throw Abort(.internalServerError)
        }
        _ = running.stop()
        return .ok
    }

    r.get("hello", ":name") { req in
        return req.parameters.get("name") ?? "<nil>"
    }

    r.get("search") { req in
        return req.query["q"] ?? "none"
    }

    let sessions = try r.grouped("sessions").grouped(c.make(SessionsMiddleware.self))
    sessions.get("get") { req -> String in
        return try req.session().data["name"] ?? "n/a"
    }
    sessions.get("set", ":value") { req -> String in
        let name = req.parameters.get("value")!
        try req.session().data["name"] = name
        return name
    }
    sessions.get("del") { req -> String in
        try req.destroySession()
        return "done"
    }

//    let client = try c.make(Client.self)
//    r.get("client") { req in
//        return client.get("http://httpbin.org/status/201").map { $0.description }
//    }
    
    let users = r.grouped("users")
    users.get { req in
        return "users"
    }
    users.get(":userID") { req in
        return "user"
    }
}
