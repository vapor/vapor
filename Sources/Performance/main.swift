import Vapor

let drop = try Droplet(middleware: [])

drop.get("plaintext") { request in
    return "Hello, world!"
}

try drop.run()
