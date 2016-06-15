import Vapor
import libc

import SocksCore
import Socks


////https://api.spotify.com/v1/search?q=beyonce&type=artist
////let address = InternetAddress(hostname: "google.com", port: 80)
//let address = InternetAddress(hostname: "api.spotify.com", port: 80)
////let address = InternetAddress(hostname: "216.58.208.46", port: 80)
//// let address = InternetAddress.localhost(port: 8080)
////let address = InternetAddress(hostname: "192.168.1.170", port: 2425)
//
//let client = try TCPClient(address: address)
//let serializer = HTTPRequestSerializer(stream: client)
//let req = Request(version: Version(major: 1, minor: 1),
//                  method: .get,
//                  path: "api.spotify.com/v1/search?q=beyonce&type=artist",
//                  host: "", // "api.spotify.com",
//                  headers: [:],
//                  data: [])
//try serializer.serialize(req)
//let response = try client.receiveAll()
//print("Got resp: \n\n\n\(response.string)")
//try client.close()

/*
 http://example.qutheory.io/json
 */
//https://api.spotify.com/v1/search?q=beyonce&type=artist
//let address = InternetAddress(hostname: "google.com", port: 80)
//let address = InternetAddress(hostname: "216.58.208.46", port: 80)
// let address = InternetAddress.localhost(port: 8080)
//let address = InternetAddress(hostname: "192.168.1.170", port: 2425)
//let uri = URI(scheme: "http", userInfo: nil, host: "www.swiftpackages.io", port: 80, path: "/test", query: nil, fragment: nil)


//let address = InternetAddress(hostname: "www.example.qutheory.io", port: 80)
//let uri = URI(scheme: "http", userInfo: nil, host: "example.qutheory.io", port: 80, path: "/json", query: nil, fragment: nil)
//let client = try TCPClient(address: address)
//let serializer = HTTPRequestSerializer(stream: StreamBuffer(client))
//let req = Request(method: .get, uri: uri, version: Version(major: 1, minor: 1), headers: [:], body: .buffer(Data([])))
//try serializer.serialize(req)
//var bytes: Bytes = []
//let next = try client.receiveAll()
//print("Got: \(next.string)")


//let address = InternetAddress(hostname: "pokeapi.co", port: 80)
extension URI {
    public typealias Scheme = String
    // TODO: Find RFC list of other defaults, implement and link source
    static let defaultPorts: [Scheme: Int] = [
        "http": 80,
        "https": 443
    ]

    // The default port associated with the scheme
    public var schemePort: Int? {
        return scheme.flatMap { scheme in URI.defaultPorts[scheme] }
    }

    init(_ str: String) throws {
        self = try URIParser.parse(uri: str.utf8)
        // if no port, but yes scheme, use scheme default if possible
        guard port == nil, let scheme = self.scheme else { return }
        port = URI.defaultPorts[scheme]
    }

}
//let u = try URI("https://api.spotify.com/v1/search?q=beyonce&type=artist")
//print(u)
print("")
import S4

//let uri = URI(scheme: "http", userInfo: nil, host: "pokeapi.co", port: 80, path: "/api/v2/pokemon/1/", query: nil, fragment: nil)
//func get(_ str: String) throws {
//    let uri = try URI(str)
//    let method = Method.get
//    let version = Version(major: 1, minor: 1)
//    let headers: Headers = [:]
//    let body: Body = .buffer(Data([]))
//    let req = Request(method: method, uri: uri, version: version, headers: headers, body: body)
//
//
//    guard let host = uri.host else { fatalError("throw appropriate error") }
//    let port = uri.port ?? 80
//
//    // TODO: Get Port from scheme
//    let address = InternetAddress(hostname: host, port: Port(port))
//    let client = try TCPClient(address: address)
//    let buffer = StreamBuffer(client)
//    let serializer = HTTPRequestSerializer(stream: buffer)
//    try serializer.serialize(req)
//    let response = try client.receiveAll()
//    print("Got response: \(response.string)")
//    try client.close()
//}

extension URI {
    // TODO: Expose public?
    private mutating func append(query appendQuery: [String: String]) {
        var new = ""
        if let existing = query {
            new += existing
            new += "&"
        }
        new += appendQuery.map { key, val in "\(key)=\(val)" } .joined(separator: "&")
        query = new
    }
}

public enum Body {
    case data(Bytes)
    case chunked((SendingStream) throws -> Void)
}

extension Headers {
    mutating func appendMetadata(for body: Body) {
        switch body {
        case .data(let bytes) where !bytes.isEmpty:
            self["Content-Length"] = bytes.count.description
        case .chunked(_):
            setTransferEncodingChunked()
        default:
            return
        }
    }

    private mutating func setTransferEncodingChunked() {
        if let encoding = self["Transfer-Encoding"] where !encoding.isEmpty {
            if encoding.hasSuffix("chunked") {
                return
            } else {
                self["Transfer-Encoding"] = encoding + ", chunked"
            }
        } else {
            self["Transfer-Encoding"] = "chunked"
        }
    }
}

extension Body {
    func makeS4Body() -> S4.Body {
        switch self {
        case .data(let bytes):
            return .buffer(Data(bytes))
        case .chunked(let sender):
            return .sender(sender)
        }
    }
}

import Foundation


//headers["Host"] = request.uri.host
////        headers["Content-Length"] = "0"
//headers["Connection"] = "close"

let DefaultHeaders: Headers = [
    "Connection": "close"
]

extension Headers {
//    func populate
}

// Until optional can use `==` on concrete types
extension Extractable where Wrapped == String {
    var isNilOrEmpty: Bool {
        guard let val = extract() else { return true }
        return val.isEmpty
    }
}

public protocol ClientDriver {
    // TODO: Using 'Any' until I build ResponseParser
    func request(_ method: S4.Method, url: String, headers: Headers, query: [String: String], body: Body) throws -> Response
}


public final class Client: ClientDriver {
    static let shared: Client = .init()

    public func request(
        _ method: S4.Method,
        url: String,
        headers: Headers = [:],
        query: [String: String] = [:],
        body: Body = .data([])) throws -> Response {

        let endpoint = url //url.hasSuffix("/") ? url : url + "/"
        var uri = try URI(endpoint)
        uri.append(query: query)

        guard let host = uri.host else { fatalError("throw appropriate error") }

        let method = Method.get
        let version = Version(major: 1, minor: 1)

        // mutable
        var headers = headers
        if headers["Connection"].isNilOrEmpty {
            headers["Connection"] = "close"
        }
        headers["Host"] = uri.host
        headers.appendMetadata(for: body)

        // TODO: Omit this need if possible
        let requestBody = body.makeS4Body()
        let req = Request(method: method, uri: uri, version: version, headers: headers, body: requestBody)

        guard
            let port = uri.port
                ?? uri.schemePort
            else { fatalError("throw appropriate error, missing port") }
        let address = InternetAddress(hostname: host, port: Port(port))
        let client = try TCPClient(address: address)

        let buffer = StreamBuffer(client)
        let serializer = HTTPRequestSerializer(stream: buffer)
        try serializer.serialize(req)
        let parser = HTTPResponseParser(stream: buffer)
        let response: Response = try parser.parse()
        _ = try? buffer.close() // TODO: Support keep-alive?
        
        return response
    }
}

public final class WebRequest {
    init(host: String) {

    }

    func get(_ path: String, query: [String: String]) throws -> Response {
        fatalError()
    }
}

//let spotifyApi = WebRequest(host: "http://api.spotify.com/v1")
//let searchResults = try spotifyApi.get("/search", query: ["q": "beyonce", "type": "album, artist"])
//let beyonceAlbum = try spotifyApi.get("/artists", query: ["id": "1234aaa"])

extension S4.Body {
    var payload: Bytes {
        switch self {
        case .buffer(let d):
            return d.bytes
        default:
            fatalError()
        }
    }
}

let strr = try Client.shared.request(.get, url: "http://example.qutheory.io/json", headers: [:])
print(strr.body.payload.string)


let poke = try Client.shared.request(.get, url: "http://pokeapi.co/api/v2/pokemon", query: ["limit": "20", "offset": "20"])
print(poke.body.payload.string)


//let client = try TCPClient(address: address)
//let serializer = HTTPRequestSerializer(stream: StreamBuffer(client))
//let req = Request(method: .get, uri: uri, version: Version(major: 1, minor: 1), headers: [:], body: .buffer(Data([])))
//try serializer.serialize(req)
//var bytes: Bytes = []
//let next = try client.receiveAll()
//print("Got: \(next.string)")



//while let next = try client.receive() {
//    bytes.append(next)
//    print("Got resp: \n\n\n\([next].string)")
//}
//
//print("Got bytes: \(bytes.string)")
//let response = try client.receiveAll()
//try client.close()

//do {
//    try client.send(bytes: "GET /\r\n\r\n".toBytes())
//    let str = try client.receiveAll().toString()
//    try client.close()
//    print("Received: \n\(str)")
//} catch {
//    print("Error \(error)")
//}

var workDir: String {
    let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
    let path = "/\(parent)/"
    return path
}

//import Foundation
//let url = NSURL.init(string: "http://example.qutheory.io/json")
//let data = NSData.init(contentsOf: url!)
//let str = String.init(data: data!, encoding: NSUTF8StringEncoding)
//print("Data: \(str)")

let config = Config(seed: JSON.object(["port": "8000"]), workingDirectory: workDir)
let app = Application(workDir: workDir, config: config)

let 😀: Response = Response(status: .ok)

app.get("ping") { _ in
    return 😀
}

//MARK: Basic

app.get("/") { request in
    return try app.view("welcome.html")
}

app.get("test") { request in
    print("Request: \(request)")
    return "123"
}

app.add(.trace, path: "trace") { request in
    return "trace request"
}

// MARK: WebSockets

app.socket("socket") { request, ws in
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

app.resource("users", controller: UserController.self)

//MARK: Request data

app.post("jsondata") { request in
    print(request.json?["hi"].string)
    return "yup"
}

//MARK: Type safe routing

app.get("test", Int.self, String.self) { request, int, string in
    return JSON([
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
app.get("users-test") { req in
    let friendName = req.data[0, "name", "friend", "name"].string
    return "Hello \(friendName)"
}

//MARK: Json

app.get("json") { request in
    return JSON([
        "number": 123,
        "text": "unicorns",
        "bool": false,
        "nested": JSON(["one", 2, false])
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
    return Response(status: .created, json: JSON(["message":"Received \(count) unicorns"]))
}

app.grouped("abort") { group in
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

    return JSON([
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

    return JSON([
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
    var response = JSON([
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
    func makeJson() -> JSON {
        return JSON([
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

    return Response(status: .ok, data: response.data)
}

app.post("multipart-image") { request in
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

    return Response(status: .ok, headers: headers, data: image.data)
}

app.get("multifile") { _ in
    var response = "<form method='post' action='/multifile/' ENCTYPE='multipart/form-data'>"

    response += "<input type='text' name='response' />"
    response += "<input type='file' name='files' multiple='multiple' />"
    response += "<button>Submit</button>"
    response += "</form>"

    return Response(status: .ok, data: response.data)
}

app.post("multifile") { request in
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

    return Response(status: .ok, headers: headers, data: file.data)
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

    return Response(status: .ok, data: response.data)
}

app.post("options") { request in
    guard let form = request.multipart, let multipart = form["options"] else {
        return "No form submited"
    }

    let selected = multipart.input ?? multipart.inputArray?.joined(separator: ", ")
    return "You have selected \"\(selected ?? "whoops!")\"\n"
}

app.post("multipart-print") { request in
    print(request.data)
    print(request.formURLEncoded)

    print(request.data["test"])
    print(request.data["test"].string)

    print(request.multipart?["test"])
    print(request.multipart?["test"]?.file)

    return JSON([
        "message": "Printed details to console"
    ])
}

//MARK: Middleware

app.grouped(AuthMiddleware()) { group in
    app.get("protected") { request in
        return JSON([
            "message": "Welcome authorized user"
        ])
    }
}

//MARK: Chunked

app.get("chunked") { request in
    return Response(headers: [
        "Content-Type": "text/plain"
    ], chunked: { stream in
        try stream.send("Counting:")
        for i in 1 ..< 10{
            sleep(1)
            try stream.send(i)
        }
        try stream.close()
    })
}

app.start()
