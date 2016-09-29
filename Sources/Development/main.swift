import JSON
import Vapor
import libc
import HTTP
import Transport
import Routing
import Cookies

#if os(Linux)
let workDir = "./Sources/Development/"
#else
var workDir: String {
    let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
    let path = "/\(parent)/"
    return path
}
#endif

import Auth
import Fluent

final class TestUser: Model, Auth.User {
    var id: Node?
    var name: String
    var exists: Bool = false

    init(name: String) {
        self.name = name
    }

    init(node: Node, in context: Context) throws {
        id = try node.extract("id")
        name = try node.extract("name")
    }

    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "id": id,
            "name": name
        ])
    }

    static func prepare(_ database: Database) throws {

    }

    static func revert(_ database: Database) throws {

    }

    static func authenticate(credentials: Credentials) throws -> Auth.User {
        guard
            let match = try TestUser.find(1)
            else {
                throw Abort.custom(status: .forbidden, message: "Invalid credentials.")
        }

        return match
    }

    static func register(credentials: Credentials) throws -> Auth.User {
        guard
            let match = try TestUser.find(1)
            else {
                throw Abort.custom(status: .forbidden, message: "Invalid credentials.")
        }
        
        return match
    }
}


let drop = Droplet(workDir: workDir)

drop.hash = CryptoHasher(method: .sha512, defaultKey: [])
drop.cipher = CryptoCipher(method: .aes128(.cbc), defaultKey: "asdfasdfasdfasdf".bytes, defaultIV: nil)



let auth = AuthMiddleware(user: TestUser.self)
drop.addConfigurable(middleware: auth, name: "auth")


let 😀 = Response(status: .ok)

import Sessions
import Node

let sessions = MemorySessions()
let s = SessionsMiddleware(sessions: sessions)


drop.post("remember") { req in
    guard let name = req.data["name"]?.string else {
        throw Abort.badRequest
    }

    try req.session().data["name"] = Node.string(name)

    return "Remebered name."
}

drop.get("remember") { req in
    guard let name = try req.session().data["name"]?.string else {
        return "Please submit your name first."
    }

    return name
}

final class UserzController: ResourceRepresentable {
    func index(_ request: Request) throws -> ResponseRepresentable {
        return try User.all().makeNode().converted(to: JSON.self)
    }

    func show(_ req: Request, _ user: User) throws -> ResponseRepresentable {
        return user
    }

    func makeResource() -> Resource<User> {
        return Resource(
            index: index,
            show: show
        )
    }
}

let users = UserzController()
drop.resource("users", users)

let hashed = try drop.hash.make("test")


enum FakeError: Error {
    case fake
}

drop.get("500") { req in
    throw FakeError.fake
}

enum FooError: Error {
    case fooServiceUnavailable
}

final class FooErrorMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        do {
            return try next.respond(to: request)
        } catch FooError.fooServiceUnavailable {
            throw Abort.custom(
                status: .badRequest,
                message: "Sorry, we were unable to query the Foo service."
            )
        }
    }
}

drop.get("sess") { req in
    print(req.cookies)
    let res = Response()
    res.cookies["test-cookie"] = "123"

    let cookie = Cookie(name: "custom", value: "42")
    res.cookies.insert(cookie)
    
    return res
}

extension Request {
    func user() throws -> TestUser {
        guard let user = try auth.user() as? TestUser else {
            throw Abort.badRequest
        }

        return user
    }
}

let memory = MemoryDriver()
TestUser.database = Database(memory)
var user = TestUser(name: "Vapor")
try user.save()

drop.post("login") { req in
    guard let credentials = req.auth.header?.bearer else {
        throw Abort.badRequest
    }

    try req.auth.login(credentials)

    return try JSON(node: [
        "message": "Logged in!"
    ])
}

let error = Abort.custom(status: .forbidden, message: "Invalid credentials.")
let protect = ProtectMiddleware(error: error)
drop.grouped(protect).group("secure") { secure in
    secure.get("user") { req in
        let user = try req.user()
        return user
    }
}

drop.get("users", Int.self) { request, userId in
    return "You requested User #\(userId)"
}

//MARK: Basic

drop.get { request in
    return try drop.view.make("welcome", [
        "name": "World"
    ])
}

// MARK: Cache

drop.get("cache") { request in
    guard let key = request.data["key"]?.string else {
        throw Abort.badRequest
    }

    return try drop.cache.get(key)?.string ?? "nil"
}

drop.post("cache") { request in
    guard
        let key = request.data["key"]?.string,
        let value = request.data["value"]?.string
    else {
        throw Abort.badRequest
    }

    try drop.cache.set(key, value)

    return "Set"
}

drop.delete("cache") { request in
    guard let key = request.data["key"]?.string else {
        throw Abort.badRequest
    }

    try drop.cache.delete(key)

    return "Deleted"
}

drop.get("client-socket") { req in
    // TODO: Find way to support multiple droplets while still having concrete reference to host / port. This will only work on one droplet ...
    let host = drop.config["servers", 0, "host"]?.string ?? "localhost"
    let port = drop.config["servers", 0, "port"]?.int ?? 80
    
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
    let name = req.data["name"]?.string ?? "beyonce"
    let spotifyResponse = try drop.client.get("https://api.spotify.com/v1/search", query: ["type": "artist", "q": name])
    
    guard
        let names = spotifyResponse.data["artists", "items", "name"]?
            .array?
            .flatMap({ $0.string })
    else {
        throw Abort.custom(status: .badRequest, message: "Could not parse response")
    }


    return try JSON(node: names)
}

drop.get("pokemon") { req in
    let limit = req.data["limit"]?.int ?? 20
    let offset = req.data["offset"]?.int ?? 0
    let pokemonResponse = try drop.client.get("http://pokeapi.co/api/v2/pokemon/", query: ["limit": limit, "offset": offset])
    guard let names = pokemonResponse.data["results", "name"]?.array?.flatMap({ $0.string }) else {
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

            if let n = response?.data["results", "name"]?.array?.flatMap({ $0.string }) {
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

drop.resource("users", UserController())

//MARK: Request data

drop.post("jsondata") { request in
    print(request.json?["hi"])
    return "yup"
}

// MARK: Type safe routing

drop.get("test", Int.self, String.self) { request, int, string in
    return try JSON(node: [
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
    let friendName = req.data[0, "name", "friend", "name"]?.string
    return "Hello \(friendName)"
}

//MARK: Json

drop.get("json") { request in
    return try JSON(node: [
        "number": 123,
        "text": "unicorns",
        "bool": false,
        "nested": try JSON(node: ["one", 2, false])
    ])
}

drop.post("json") { request in
    //parse a key inside the received json
    guard let count = request.data["unicorns"]?.int else {
        throw Abort.custom(status: .badRequest, message: "No unicorn count provided")
    }
    return "Received \(count) unicorns"
}

drop.post("form") { request in
    guard let name = request.data["name"]?.string else {
        throw Abort.custom(status: .badRequest, message: "No name provided")
    }

    return "Hello \(name)"
}

drop.get("redirect") { request in
    return Response(redirect: "http://qutheory.io:8001")
}

drop.group("abort") { group in
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
        throw Abort.serverError
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
    guard let name = request.data["name"]?.string else {
        throw Abort.badRequest
    }
    try request.session().data["name"] = Node.string(name)

    return "Session set"
}

drop.get("session") { request in
    guard let name = try request.session().data["name"]?.string else {
        return "No session data"
    }

    return name
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
    var response = try JSON(node: [
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

extension Employee: JSONRepresentable {
    func makeJSON() throws -> JSON {
        return try JSON(node: [
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

    var headers: [HeaderKey: String] = [:]

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

    var headers: [HeaderKey: String] = [:]

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

    return Response(status: .ok, body: .data(response.bytes))
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
    print(request.data["test"]?.string)

    print(request.multipart?["test"])
    print(request.multipart?["test"]?.file)

    return try JSON(node: [
        "message": "Printed details to console"
    ])
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

struct TestCollection: RouteCollection, EmptyInitializable {
    typealias Wrapped = Responder
    func build<Builder : RouteBuilder>(_ builder: Builder) where Builder.Value == Responder {
        builder.get("test") { request in
            return "Test Collection"
        }
    }
}

drop.grouped("test-collection").collection(TestCollection.self)

drop.get("async") { request in
    return try Response.async { portal in
        _ = try background {
            do {
                let beyonceQuery = "https://api.spotify.com/v1/search/?q=beyonce&type=artist"
                let response = try drop.client.get(beyonceQuery)
                let artists = response.data["artists", "items", "name"]?.array ?? []
                let artistsJSON = artists.flatMap { $0.string }
                let js = try! JSON(node: artistsJSON)
                portal.close(with: js)
            } catch {
                portal.close(with: error)
            }
        }
    }
}

let config = try TLS.Config(
    mode: .server,
    certificates: .files(certificateFile: "/Users/tanner/Desktop/certs/cert.pem", privateKeyFile: "/Users/tanner/Desktop/certs/key.pem", signature: .selfSigned),
    verifyHost: true,
    verifyCertificates: true
)

drop.run(servers: [
    "test": ("gertrude.codes", 8080, .none),
    "secure": ("gertrude.codes", 8443, .tls(config)),
])
