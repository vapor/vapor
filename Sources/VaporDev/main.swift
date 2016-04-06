import Vapor

let app = Application()

app.hash.key = app.config.get("app.hash.key", "default-key")

//MARK: Basic

app.get("/") { request in
    return try app.view("welcome.html")
}

app.get("test") { request in
    return "123"
}

//MARK: Resource

app.resource("users", controller: UserController.self)

//MARK: Request data

app.post("jsondata") { request in
    print(request.data.json?["hi"]?.string)
    return "yup"
}

//MARK: Type safe routing

app.get("test", Int.self, String.self) { request, int, string in
    return Json([
        "message": "Int \(int) String \(string)"
    ])
}

//MARK: Json

app.get("json") { request in
    return Json([
        "number": 123,
        "text": "unicorns",
        "bool": false,
        "nested": ["one", 2, false]
    ])
}

app.post("json") { request in
    //parse a key inside the received json
    guard let count = request.data["unicorns"]?.int else {
        return Response(error: "No unicorn count provided")
    }
    return "Received \(count) unicorns"
}

app.post("form") { request in
    guard let name = request.data["name"]?.string else {
        return Response(error: "No name provided")
    }

    return "Hello \(name)"
}

app.get("redirect") { request in
    return Response(redirect: "http://qutheory.io:8001")
}

app.post("json2") { request in
    //parse a key inside the received json
    guard let count = request.data["unicorns"]?.int else {
        return Response(error: "No unicorn count provided")
    }
    return Response(status: .created, json: Json(["message":"Received \(count) unicorns"]))
}

app.group("abort") {
    app.get("400") { request in
        throw Abort.badRequest
    }

    app.get("404") { request in
        throw Abort.notFound
    }

    app.get("420") { request in
        throw Abort.custom(status: .enhanceYourCalm, message: "Enhance your calm")
    }

    app.get("500") { request in
        throw Abort.internalServerError
    }
}

enum Error: ErrorProtocol {
    case Unhandled
}

app.get("error") { request in
    throw Error.Unhandled
}

//MARK: Session

app.get("session") { request in
    request.session?["name"] = "Vapor"
    return "Session set"
}

app.get("login") { request in
    guard let id = request.session?["id"] else {
        throw Abort.badRequest
    }

    return Json([
        "id": id
    ])
}

app.post("login") { request in
    guard
        let email = request.data["email"]?.string,
        let password = request.data["password"]?.string
    else {
        throw Abort.badRequest
    }

    guard email == "user@qutheory.io" && password == "test123" else {
        throw Abort.badRequest
    }

    request.session?["id"] = "123"

    return Json([
        "message": "Logged in"
    ])
}

app.get("cookies") { request in
    var response = Json([
        "cookies": "\(request.cookies)"
    ]).makeResponse()

    response.cookies["cookie-1"] = "value-1"
    response.cookies["hello"] = "world"

    return response
}

//MARK: Middleware

app.middleware(AuthMiddleware()) {
    app.get("protected") { request in
        return Json([
            "message": "Welcome authorized user"
        ])
    }
}

//MARK: Async

app.get("async") { request in
    var response = Response(async: { stream in
        try stream.send("hello".data)
    })
    response.headers["Content-Type"] = "text/plain"
    response.headers["Transfer-Encoding"] = ""
    response.headers["Content-Length"] = 5
    return response
}

app.start()
