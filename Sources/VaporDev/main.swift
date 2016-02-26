import Vapor

let app = Application()

app.get("/") { request in
    return "Welcome to Vapor"
}

app.get("test") { request in
    return "123"
}

app.start(port: 8080)
