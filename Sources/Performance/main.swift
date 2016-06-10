import Vapor

let app = Application()

app.get("plaintext") { request in
    return Response(body: Data("Hello, world!".utf8))
}

app.globalMiddleware = []

app.start()
