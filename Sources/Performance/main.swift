import Vapor

let app = Droplet()

app.get("plaintext") { request in
    return "Hello, world"
}

app.globalMiddleware = []

app.serve()
