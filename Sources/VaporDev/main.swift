import Vapor

let app = Application()

app.get("/") { request in
    return try app.view("welcome.html")
}

app.get("test") { request in
    return "123"
}

app.get("json") { request in
    return Json(
        [
            "number":123,
            "text": "unicorns",
            "nested": ["one", 2, false]
        ]
    )
}

let i = Int.self
let s = String.self

app.get("test", i, s) { request, int, string in
    return try Json([
        "message": "Int \(int) String \(string)"
    ])
}

app.get("session") { request in 
    request.session?["name"] = "Vapor"
    return "Session set"
}

app.post("json") { request in
    //parse a key inside the received json
    guard let count = request.data["unicorns"]?.int else {
        return Response(error: "No unicorn count provided")
    }
    return "Received \(count) unicorns"
}

app.post("json2") { request in
    //parse a key inside the received json
    guard let count = request.data["unicorns"]?.int else {
        return Response(error: "No unicorn count provided")
    }
    return try Response(status: .Created, json: Json(["message":"Received \(count) unicorns"]))
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

app.start(port: 8023)
