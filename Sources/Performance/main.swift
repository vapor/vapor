import Vapor
import Engine

let drop = Droplet()

drop.get("plaintext") { request in
    return "Hello, world"
}

drop.globalMiddleware = []

drop.serve()
