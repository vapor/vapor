import Vapor
import Engine


final class TestMiddleware: Middleware {
    init() { }
    func respond(to request: HTTPRequest, chainingTo next: HTTPResponder) throws -> HTTPResponse {
        print("⚠️ TEST MIDDLEWARE CALLED")
        let response = try next.respond(to: request)
        return response
    }
}



let drop = Droplet()

drop.get("plaintext") { request in
    return "Hello, world"
}

drop.group("users") { group in
    group.get { request in
        return "index"
    }

    group.group("deeper") { sub in
        sub.post("hello") { request in
            return "echo!!"
        }

        sub.get(Int.self, Int.self, Int.self) { req, one, two, three in
            return "\(one) \(two) \(three)"
        }

        sub.group(TestMiddleware()) { group in
            group.get("middleware") { request in
                return "got called"
            }
        }
    }

    group.get("tests", Int.self) { request, id in
        return "type safe id: \(id)"
    }
}

drop.globalMiddleware = []



drop.serve()
