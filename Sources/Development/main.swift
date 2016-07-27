import JSON
import Vapor
import libc
import Engine

#if os(Linux)
let workDir = "./Sources/Development"
#else
var workDir: String {
    let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
    let path = "/\(parent)/"
    return path
}
#endif

let drop = Droplet(workDir: workDir)
let 😀 = Response(status: .ok)

//MARK: Basic

drop.get { request in
    return try drop.view("welcome.html")
}

drop.get("client-socket") { req in
    // TODO: Find way to support multiple droplets while still having concrete reference to host / port. This will only work on one droplet ...
    let host = drop.config["servers", 0, "host"].string ?? "localhost"
    let port = drop.config["servers", 0, "port"].int ?? 80
    
    _ = try? WebSocket.background(to: "ws://\(host):\(port)/server-socket-responder") { (ws) in
        ws.onText = { ws, text in
            print("[Client] received - \(text)")
        }

        ws.onClose = { _ in
            print("[Client] closed.....")
        }
    }

    return "Beginning client socket test, check your console ..."
}

drop.socket("server-socket-responder") { req, ws in
    let top = 10
    for i in 1...top {
        sleep(1)
        try ws.send("\(i) of \(top)")
    }

    sleep(1)
    print("[Server] initiating close")
    try ws.close()
}

drop.get("ping") { _ in
    return 😀
}

drop.get("spotify-artists") { req in
    let name = req.data["name"].string ?? "beyonce"
    let spotifyResponse = try drop.client.get("https://api.spotify.com/v1/search", query: ["type": "artist", "q": name])
    
    guard
        let names = try spotifyResponse.data["artists", "items", "name"]
            .array?
            .flatMap({ $0.string })
            .map({ try JSON($0) })
    else {
        throw Abort.custom(status: .badRequest, message: "Could not parse response")
    }

    return JSON.array(names)
}

drop.get("pokemon") { req in
    let limit = req.data["limit"].int ?? 20
    let offset = req.data["offset"].int ?? 0
    let pokemonResponse = try drop.client.get("http://pokeapi.co/api/v2/pokemon/", query: ["limit": limit, "offset": offset])
    guard let names = pokemonResponse.data["results", "name"].array?.flatMap({ $0.string }) else {
        throw Abort.custom(status: .badRequest, message: "Didn't parse JSON correctly")
    }

    return names.joined(separator: "\n")
}

drop.get("pokemon-multi") { [weak drop] req in
    return Response { chunker in
        /**
         Advanced usage, maintain connection
         */
        let pokemonClient = try drop?.client.make(scheme: "http", host: "pokeapi.co")
        for i in 0 ..< 2 {
            let response = try pokemonClient?.get(path: "/api/v2/pokemon/", query: ["limit": 20, "offset": i])

            if let n = response?.data["results", "name"].array?.flatMap({ $0.string }) {
                try chunker.send(n.joined(separator: "\n"))
            }
        }

        try chunker.close()
    }
}

drop.get("test") { request in
    print("Request: \(request)")
    return "123"
}

drop.add(.trace, path: "trace") { request in
    return "trace request"
}

drop.socket("socket") { request, ws in
    try ws.send("WebSocket Connected :)")

    ws.onText = { ws, text in
        try ws.send("You said \(text)!")

        if text == "stop" {
            ws.onText = nil
            try ws.send("🚫 stopping connection listener -- socket remains open")
        }

        if text == "close" {
            try ws.send("... closing 👋")
            try ws.close()
        }
    }

    ws.onClose = { ws, status, reason, clean in
        print("Did close w/ status \(status) reason \(reason)")
    }
}

//MARK: Resource

drop.resource("users", UserController.self)

//MARK: Request data

drop.post("jsondata") { request in
    print(request.json?["hi"])
    return "yup"
}

//MARK: Type safe routing

drop.get("test", Int.self, String.self) { request, int, string in
    return try JSON([
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
drop.get("users-test") { req in
    let friendName = req.data[0, "name", "friend", "name"].string
    return "Hello \(friendName)"
}

//MARK: Json

drop.get("json") { request in
    return try JSON([
        "number": 123,
        "text": "unicorns",
        "bool": false,
        "nested": try JSON(["one", 2, false])
    ])
}

drop.post("json") { request in
    //parse a key inside the received json
    guard let count = request.data["unicorns"].int else {
        throw Abort.custom(status: .badRequest, message: "No unicorn count provided")
    }
    return "Received \(count) unicorns"
}

drop.post("form") { request in
    guard let name = request.data["name"].string else {
        throw Abort.custom(status: .badRequest, message: "No name provided")
    }

    return "Hello \(name)"
}

drop.get("redirect") { request in
    return Response(redirect: "http://qutheory.io:8001")
}

drop.grouped("abort") { group in
    group.get("400") { request in
        throw Abort.badRequest
    }

    group.get("404") { request in
        throw Abort.notFound
    }

    group.get("420") { request in
        throw Abort.custom(status: .enhanceYourCalm, message: "Enhance your calm")
    }

    group.get("500") { request in
        throw Abort.internalServerError
    }
}

enum Error: Swift.Error {
    case Unhandled
}

drop.get("error") { request in
    throw Error.Unhandled
}

//MARK: Session

drop.post("session") { request in
    guard let name = request.data["name"].string else {
        throw Abort.badRequest
    }
    request.session?["name"] = name

    return "Session set"
}

drop.get("session") { request in
    guard let name = request.session?["name"] else {
        return "No session data"
    }

    return name
}
drop.get("login") { request in
    guard let id = request.session?["id"] else {
        throw Abort.badRequest
    }

    return try JSON([
        "id": id
    ])
}

drop.post("login") { request in
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

    return try JSON([
        "message": "Logged in"
    ])
}

/**
    This example is in the docs. If it changes,
    make sure to update the Response section.
 */
drop.get("cookie") { request in
    var response = Response(status: .ok, body: "Cookie set")
    response.cookies["id"] = "123"

    return response
}


drop.get("cookies") { request in
    var response = try JSON([
        "cookies": "\(request.cookies)"
        ])
        .makeResponse(for: request)

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

extension Employee: JSONRepresentable {
    func makeNode() throws -> Node {
        return try Node([
            "name": name.value,
            "email": email.value
        ])
    }
}

drop.post("validation") { request in
    let employee = try Employee(request: request)
    return try employee.makeJSON()
}

//MARK: Forms

drop.get("multipart-image") { _ in
    var response = "<form method='post' action='/multipart-image/' ENCTYPE='multipart/form-data'>"

    response += "<input type='text' name='name' />"
    response += "<input type='file' name='image' accept='image/*' />"
    response += "<button>Submit</button>"
    response += "</form>"

    return Response(body: response)
}

drop.post("multipart-image") { request in
    guard let form = request.multipart else {
        throw Abort.badRequest
    }

    guard let namePart = form["name"]?.input else {
        throw Abort.badRequest
    }

    guard let image = form["image"]?.file else {
        throw Abort.badRequest
    }

    var headers: Headers = [:]

    if let mediaType = image.type {
        headers["Content-Type"] = mediaType
    }

    return Response(status: .ok, headers: headers, body: image.data)
}

drop.get("multifile") { _ in
    var response = "<form method='post' action='/multifile/' ENCTYPE='multipart/form-data'>"

    response += "<input type='text' name='response' />"
    response += "<input type='file' name='files' multiple='multiple' />"
    response += "<button>Submit</button>"
    response += "</form>"

    return Response(body: response)
}

drop.post("multifile") { request in
    guard let form = request.multipart else {
        throw Abort.badRequest
    }

    guard let response = form["response"]?.input, let number = Int(response) else {
        throw Abort.badRequest
    }

    guard let files = form["files"]?.files else {
        throw Abort.badRequest
    }

    guard files.count > number else {
        throw Abort.badRequest
    }

    let file = files[number]

    var headers: Headers = [:]

    if let mediaType = file.type {
        headers["Content-Type"] = mediaType
    }

    return Response(status: .ok, headers: headers, body: .data(file.data))
}

drop.get("options") { _ in
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

    return HTTPResponse(status: .ok, body: .data(response.bytes))
}

drop.post("options") { request in
    guard let form = request.multipart, let multipart = form["options"] else {
        return "No form submited"
    }

    let selected = multipart.input ?? multipart.inputArray?.joined(separator: ", ")
    return "You have selected \"\(selected ?? "whoops!")\"\n"
}

drop.post("multipart-print") { request in
    print(request.data)
    print(request.formURLEncoded)

    print(request.data["test"])
    print(request.data["test"].string)

    print(request.multipart?["test"])
    print(request.multipart?["test"]?.file)

    return try JSON([
        "message": "Printed details to console"
    ])
}

//MARK: Middleware

drop.grouped(AuthMiddleware()) { group in
    drop.get("protected") { request in
        return try JSON([
            "message": "Welcome authorized user"
        ])
    }
}

//MARK: Chunked

drop.get("chunked") { request in
    return Response(headers: ["Content-Type": "text/plain"]) { stream in
        try stream.send("Counting:")
        for i in 1 ..< 10{
            sleep(1)
            try stream.send(i)
        }
        try stream.close()
    }
}

#if !os(Linux)
    /*
    Temporarily not available on Linux because of Dispatch APIs
    */
    drop.get("async") { request in
        return try Response.async { promise in
            _ = try background {
                do {
                    let beyonceQuery = "https://api.spotify.com/v1/search/?q=beyonce&type=artist"
                    let response = try HTTPClient<FoundationStream>.get(beyonceQuery)
                    let artists = response.data["artists", "items", "name"].array ?? []
                    let artistsJSON = artists.flatMap { $0.string } .map { JSON.string($0) }
                    let js = JSON.array(artistsJSON)
                    promise.resolve(with: js)
                } catch {
                    promise.reject(with: error)
                }
            }
        }
    }
#endif

drop.serve()
