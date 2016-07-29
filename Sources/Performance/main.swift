import Vapor
import HTTP

let drop = Droplet()

drop.get("plaintext") { request in
    return "Hello, world"
}

drop.globalMiddleware = []

drop.serve()
