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

drop.get { request in
    return "root"
}

drop.get("plaintext") { request in
    return "Hello, world"
}

final class User: StringInitializable {
    var id: String
    init(id: String) {
        self.id = id
    }

    convenience init?(from string: String) throws {
        self.init(id: string)
    }
}

drop.resource("users", User.self) { users in
    users.show = { request, user in
        return "Showing user \(user.id)"
    }

    users.index = { request in
        return "Showing all users"
    }
}

drop.group("testingx") { group in
    print("Going testingx...")
    group.get { request in
        return "index"
    }

    group.group(host: "0.0.0.0") { special in
        print("Going host only...")
        special.get("host-only") { request in
            return "for the host only"
        }
    }

    group.get("easy") { req in
        return "sup"
    }

    group.group("deeper") { sub in
        print("Going deeper...")
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
