import Vapor

struct Creds: Content {
    var email: String
    var password: String
}

public func routes(_ app: Application) throws {
    app.on(.GET, "ping", body: .stream) { req in
        return "123" as StaticString
    }


    // ( echo -e 'POST /slow-stream HTTP/1.1\r\nContent-Length: 1000000000\r\n\r\n'; dd if=/dev/zero; ) | nc localhost 8080
    app.on(.POST, "slow-stream", body: .stream) { req -> EventLoopFuture<String> in
        let done = req.eventLoop.makePromise(of: String.self)

        var total = 0
        req.body.drain { result in
            let promise = req.eventLoop.makePromise(of: Void.self)

            switch result {
            case .buffer(let buffer):
                req.eventLoop.scheduleTask(in: .milliseconds(1000)) {
                    total += buffer.readableBytes
                    promise.succeed(())
                }
            case .error(let error):
                done.fail(error)
            case .end:
                promise.succeed(())
                done.succeed(total.description)
            }

            // manually return pre-completed future
            // this should balloon in memory
            // return req.eventLoop.makeSucceededFuture(())
            
            // return real future that indicates bytes were handled
            // this should use very little memory
            return promise.futureResult
        }

        return done.futureResult
    }
    
    app.post("login") { req -> String in
        let creds = try req.content.decode(Creds.self)
        return "\(creds)"
    }
    
    app.on(.POST, "large-file", body: .collect(maxSize: 1_000_000_000)) { req -> String in
        return req.body.data?.readableBytes.description  ?? "none"
    }

    app.get("json") { req -> [String: String] in
        return ["foo": "bar"]
    }.description("returns some test json")
    
    app.webSocket("ws") { req, ws in
        ws.onText { ws, text in
            ws.send(text.reversed())
            if text == "close" {
                ws.close(promise: nil)
            }
        }

        let ip = req.remoteAddress?.description ?? "<no ip>"
        ws.send("Hello 👋 \(ip)")
    }
    
    app.on(.POST, "file", body: .stream) { req -> EventLoopFuture<String> in
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
            return req.eventLoop.makeSucceededFuture(())
        }
        return promise.futureResult
    }

    app.get("shutdown") { req -> HTTPStatus in
        guard let running = req.application.running else {
            throw Abort(.internalServerError)
        }
        _ = running.stop()
        return .ok
    }

    let cache = MemoryCache()
    app.get("cache", "get", ":key") { req -> String in
        guard let key = req.parameters.get("key") else {
            throw Abort(.internalServerError)
        }
        return "\(key) = \(cache.get(key) ?? "nil")"
    }
    app.get("cache", "set", ":key", ":value") { req -> String in
        guard let key = req.parameters.get("key") else {
            throw Abort(.internalServerError)
        }
        guard let value = req.parameters.get("value") else {
            throw Abort(.internalServerError)
        }
        cache.set(key, to: value)
        return "\(key) = \(value)"
    }

    app.get("hello", ":name") { req in
        return req.parameters.get("name") ?? "<nil>"
    }

    app.get("search") { req in
        return req.query["q"] ?? "none"
    }

    let sessions = app.grouped("sessions")
        .grouped(SessionsMiddleware(session: app.sessions.driver))
    sessions.get("get") { req -> String in
        return req.session.data["name"] ?? "n/a"
    }
    sessions.get("set", ":value") { req -> String in
        let name = req.parameters.get("value")!
        req.session.data["name"] = name
        return name
    }
    sessions.get("del") { req -> String in
        req.destroySession()
        return "done"
    }

    app.get("client") { req in
        return req.client.get("http://httpbin.org/status/201").map { $0.description }
    }

    app.get("client-json") { req -> EventLoopFuture<String> in
        struct HTTPBinResponse: Decodable {
            struct Slideshow: Decodable {
                var title: String
            }
            var slideshow: Slideshow
        }
        return req.client.get("http://httpbin.org/json")
            .flatMapThrowing { try $0.content.decode(HTTPBinResponse.self) }
            .map { $0.slideshow.title }
    }
    
    let users = app.grouped("users")
    users.get { req in
        return "users"
    }
    users.get(":userID") { req in
        return req.parameters.get("userID") ?? "no id"
    }

    app.directory.viewsDirectory = "/Users/tanner/Desktop"
    app.get("view") { req -> EventLoopFuture<View> in
        req.view.render("hello.txt", ["name": "world"])
    }

    app.get("secret") { (req) -> EventLoopFuture<String> in
        return Environment
            .secret(key: "PASSWORD_SECRET", fileIO: req.application.fileio, on: req.eventLoop)
            .unwrap(or: Abort(.badRequest))
    }
}
