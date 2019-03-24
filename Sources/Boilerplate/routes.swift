import Vapor

struct Creds: Content {
    var email: String
    var password: String
}

public func routes(_ r: Routes, _ c: Container) throws {
    r.get("ping") { _, _ in
        return "123" as StaticString
    }
    
    r.post("login") { (creds: Creds, ctx: Context) -> String in
        return "\(creds)"
    }
    
    r.on(.POST, to: "large-file", bodyStream: .collect(maxSize: 1_000_000_000)) { (req: HTTPRequest, ctx: Context) -> String in
        return req.body.count?.description ?? "none"
    }

    r.get("json") { (req: HTTPRequest, ctx: Context) -> [String: String] in
        return ["foo": "bar"]
    }.description("returns some test json")
    
    r.webSocket("ws") { (req: HTTPRequest, ctx: Context, ws: WebSocket) -> () in
        ws.onText { ws, text in
            ws.send(text: text.reversed())
        }
        
        let ip = ctx.channel.remoteAddress?.description ?? "<no ip>"
        ws.send(text: "Hello 👋 \(ip)")
    }
    
    r.on(.POST, to: "file", bodyStream: .allow) { (req: HTTPRequest, ctx: Context) -> EventLoopFuture<String> in
        guard let stream = req.body.stream else {
            return ctx.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Expected streaming body."))
        }
        let promise = ctx.eventLoop.makePromise(of: String.self)
        stream.read { result, stream in
            switch result {
            case .chunk(let chunk):
                debugPrint(chunk)
            case .error(let error):
                promise.fail(error)
            case .end:
                promise.succeed("Done")
            }
        }
        return promise.futureResult
    }

//    r.get("hello", String.parameter) { req in
//        return try req.parameters.next(String.self)
//    }
//
//    router.get("search") { req in
//        return req.query["q"] ?? "none"
//    }
//
    let sessions = try r.grouped("sessions").grouped(c.make(SessionsMiddleware.self))
    sessions.get("get") { (req: HTTPRequest, ctx: Context) -> String in
        return try ctx.session().data["name"] ?? "n/a"
    }
    sessions.get("set", ":value") { (req: HTTPRequest, ctx: Context) -> String in
        let name = ctx.parameters.get("value")!
        try ctx.session().data["name"] = name
        return name
    }
    sessions.get("del") { (req: HTTPRequest, ctx: Context) -> String in
        try ctx.destroySession()
        return "done"
    }

    let client = try c.make(Client.self)
    r.get("client") { (req: HTTPRequest, ctx: Context) in
        return client.get("http://httpbin.org/status/201").map { $0.description }
    }
    
    let users = r.grouped("users")
    users.get { (req: HTTPRequest, ctx: Context) in
        return "users"
    }
    users.get(.parameter("userID")) { (req: HTTPRequest, ctx: Context) in
        return "user"
    }
}
