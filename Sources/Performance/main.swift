import Vapor

let app = Application()

app.get("plaintext") { request in
    return "Hello, world!"
}

app.start()
