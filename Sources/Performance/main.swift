import Vapor

let app = Application()

app.get("plaintext") { request in
    return "Hello, world"
}

app.globalMiddleware = []

app.start()
