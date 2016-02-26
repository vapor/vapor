import Vapor

let app = Application()

app.get("/") { request in
    return "Welcome to Vapor"
}

app.get("test") { request in
    return "123"
}

app.group("abort") {
    app.get("400") { request in
        throw Abort.BadRequest
    }
    
    app.get("404") { request in
        throw Abort.NotFound
    }
    
    app.get("420") { request in
        throw Abort.Custom(status: .Custom(420), message: "Enhance your calm")
    }
    
    app.get("500") { request in
        throw Abort.InternalServerError
    }
}

app.resource("resource", controller: MyController.self)

app.start(port: 8080)
