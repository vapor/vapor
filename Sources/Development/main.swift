import Vapor
import S4

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
    print(request.data.json?["hi"].string)
    return "yup"
}

//MARK: Type safe routing

app.get("test", Int.self, String.self) { request, int, string in
    return Json([
        "message": "Int \(int) String \(string)"
    ])
}

/* Expected Users Format
 [
    [
        "name" : "joe",
        "friend" : [
            "name" : "joe"
        ]
    ]
 ]
 */
app.get("users") { req in
    let friendName = req.data[0, "name", "friend", "name"].string
    return "Hello \(friendName)"
}

//MARK: Json

app.get("json") { request in
    return Json([
        "number": 123,
        "text": "unicorns",
        "bool": false,
        "nested": Json(["one", 2, false])
    ])
}

app.post("json") { request in
    //parse a key inside the received json
    guard let count = request.data["unicorns"].int else {
        return Response(error: "No unicorn count provided")
    }
    return "Received \(count) unicorns"
}

app.post("form") { request in
    guard let name = request.data["name"].string else {
        return Response(error: "No name provided")
    }

    return "Hello \(name)"
}

app.get("redirect") { request in
    return Response(redirect: "http://qutheory.io:8001")
}

app.post("json2") { request in
    //parse a key inside the received json
    guard let count = request.data["unicorns"].int else {
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

/**
    This example is in the docs. If it changes,
    make sure to update the Response section.
 */
app.get("cookie") { request in
    var response = Response(status: .ok, text: "Cookie set")
    response.cookies["id"] = "123"

    return response
}


app.get("cookies") { request in
    var response = Json([
        "cookies": "\(request.cookies)"
    ]).makeResponse()

    response.cookies["cookie-1"] = "value-1"
    response.cookies["hello"] = "world"

    return response
}

class Name: ValidationSuite {
    static func validate(input value: String) throws {
        let evaluation = OnlyAlphanumeric.self
            && Count.min(5)
            && Count.max(20)

        try evaluation.validate(input: value)
    }
}

class Employee {
    var name: Valid<Name>
    var email: Valid<Email>

    init(request: Request) throws {
        name = try request.data["name"].validated()
        email = try request.data["email"].validated()
    }
}

extension Employee: JsonRepresentable {
    func makeJson() -> Json {
        return Json([
            "name": name.value,
            "email": email.value
        ])
    }
}

app.post("validation") { request in
    let employee = try Employee(request: request)
    return employee
}

//MARK: Forms

app.get("multipart-image") { _ in
    var response = "<form method='post' action='/multipart-image/' ENCTYPE='multipart/form-data'>"

    response += "<input type='text' name='name' />"
    response += "<input type='file' name='image' accept='image/*' />"
    response += "<button>Submit</button>"
    response += "</form>"

    return Response(status: .ok, html: response)
}

app.post("multipart-image") { request in
    guard let form = request.data.formEncoded else {
        return "No form submited"
    }

    guard let namePart = form["name"]?.input else {
        return "No name provided"
    }

    guard let image = form["image"]?.file else {
        return "No image provided"
    }

    var headers: Headers = [:]
    
    if let mediaType = image.type {
        let header = Header([mediaType.type + "/" + mediaType.subtype])
        headers["Content-Type"] = header
    }

    return Response(status: .ok, headers: headers, body: image.data)
}

app.get("multifile") { _ in
    var response = "<form method='post' action='/multifile/' ENCTYPE='multipart/form-data'>"
    
    response += "<input type='text' name='response' />"
    response += "<input type='file' name='files' multiple='multiple' />"
    response += "<button>Submit</button>"
    response += "</form>"
    
    return Response(status: .ok, html: response)
}

app.post("multifile") { request in
    guard let form = request.data.formEncoded else {
        return "No form submited"
    }
    
    guard let response = form["response"]?.input, let number = Int(response) else {
        return "No response number provided"
    }

    guard let files = form["files"]?.files else {
        return "No image provided"
    }

    guard files.count > number else {
        return "Response number doesn't exist"
    }

    let file = files[number]

    var headers: Headers = [:]
    
    if let mediaType = file.type {
        let header = Header([mediaType.type + "/" + mediaType.subtype])
        headers["Content-Type"] = header
    }

    return Response(status: .ok, headers: headers, body: file.data)
}

app.get("options") { _ in
    var response = "<form method='post' action='/options/' ENCTYPE='multipart/form-data'>"
    
    response += "<select name='options' multiple='multiple'>"
    response += "<option value='0'>0</option>"
    response += "<option value='1'>1</option>"
    response += "<option value='2'>2</option>"
    response += "<option value='3'>3</option>"
    response += "<option value='4'>4</option>"
    response += "<option value='5'>5</option>"
    response += "<option value='6'>6</option>"
    response += "<option value='7'>7</option>"
    response += "<option value='8'>8</option>"
    response += "<option value='9'>9</option>"
    response += "</select>"
    response += "<button>Submit</button>"
    response += "</form>"
    
    return Response(status: .ok, html: response)
}

app.post("options") { request in
    guard let form = request.data.formEncoded else {
        return "No form submited"
    }
    
    var response = ""
    
    for string in form["options"]?.inputArray ?? [] {
        response += "You have selected \"\(string)\"\n"
    }
    
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

app.start(port: 8080)
