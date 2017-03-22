import Vapor

let drop = try Droplet()

drop.get("plaintext") { request in
    return "Hello, world"
}

drop.middleware = []

try drop.run()
