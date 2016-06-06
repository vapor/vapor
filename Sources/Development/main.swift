import Vapor
import S4

var workDir: String {
    let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
    let path = "/\(parent)/"
    return path
}

let config = Config(seed: JSON.object(["port": "8000"]), workingDirectory: workDir)
let app = Application(workDir: workDir, config: config)

//MARK: Basic

app.get("/") { request in
    return try app.view("welcome.html")
}

app.get("test") { request in
    print("Request: \(request)")
    return "123"
}

// Create NSData object
//NSData *nsdata = [@"iOS Developer Tips encoded in Base64"
//    dataUsingEncoding:NSUTF8StringEncoding];
//
//// Get NSString from NSData object in Base64
//NSString *base64Encoded = [nsdata base64EncodedStringWithOptions:0];
//
//// Print the Base64 encoded string
//NSLog(@"Encoded: %@", base64Encoded);
//
//// Let's go the other way...
//
//// NSData from the Base64 encoded str
//NSData *nsdataFromBase64String = [[NSData alloc]
//    initWithBase64EncodedString:base64Encoded options:0];
//
//// Decoded NSString from the NSData
//NSString *base64Decoded = [[NSString alloc]
//    initWithData:nsdataFromBase64String encoding:NSUTF8StringEncoding];
//NSLog(@"Decoded: %@", base64Decoded);
import Foundation
import SHA1

extension String {
    // TODO: Fewer foundation deps
    func makeWebSocketSecKeyExchange() -> String {
        // UUID defined here: https://tools.ietf.org/html/rfc6455#section-1.3
        let HashKey = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let combined = self.trim() + HashKey
        let shaBytes = SHA1.calculate(combined)
        let endMarker = NSData(bytes: shaBytes, length: shaBytes.count)
        let hashed = endMarker.base64EncodedString(.encoding64CharacterLineLength)
        return hashed
    }
    func toBase64() -> String {
        let d = data(using: NSUTF8StringEncoding)
        return d!.base64EncodedString(.encoding64CharacterLineLength)
//        return d!.base64EncodedData(NSDataBase64EncodingOptions.encoding64CharacterLineLength)
    }

    static func fromBase64(_ string: String) -> String {
        let d = NSData.init(base64Encoded: string, options: .ignoreUnknownCharacters)
        return String.init(data: d!, encoding: NSUTF8StringEncoding)!
    }
}

// TODO: Do test from RFC
//let HashKey = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
//let combined = "dGhlIHNhbXBsZSBub25jZQ==" + HashKey
//let shaBytes = SHA1.calculate(combined)
//var endMarker = NSData(bytes: shaBytes, length: shaBytes.count)
//let hashed = endMarker.base64EncodedString(.encoding64CharacterLineLength)
//print("HASHED: \(hashed)")
//print("")

//app.get("socket") { request in
//    print("Get socket: \(request)")
//    func socketHandler(_ socket: Stream) throws {
//        print("About to send\n\n")
//        try socket.send(Data([0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]))
//        print("Sent ---\n\n Receiving --- \n\n")
////        let received = try socket.receive(upTo: 1024)
////        let msg = try MessageParser.parseInput(Data(received))
////        print("Received message: \(msg)")
////        print("\n\nPayload: \(try msg.payload.toString())\n\n")
////        print("")
//
////        try socket.send(Data([0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]))
////        try socket.send(Data([0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]))
//        var c = 1
//        var fragmentedMessage: [String] = []
//        while true {
//            c += 1
//            // need to iterate through message
////            let next = try socket.receive(upTo: 1024)
////            guard !next.isEmpty else { continue }
//            let newMsg = try MessageParser.parse(stream: socket)
//            let str = try newMsg.payload.toString()
//
//            var respondMsg: String = ""
//            if newMsg.isFragmentHeader {
//                fragmentedMessage.append(str)
//                continue
//            } else if newMsg.isFragmentBody {
//                fragmentedMessage.append(str)
//                continue
//            } else if newMsg.isFragmentFooter {
//                fragmentedMessage.append(str)
//                respondMsg = fragmentedMessage.joined(separator: "")
//                fragmentedMessage = []
//            } else {
//                respondMsg = "Hello there again, this has been \(c) times, and now it's \(NSDate())"
//            }
//
//            print("\n\n[MSG]:\n\n\t\(str)\n\n")
////            let message = "Hello there again, this has been \(c) times, and now it's \(NSDate())"
////            let message = "ECHO: \(str)"
////            let msgBytes = Data(message)
//            let msg = WebSock.Message.respondToClient(respondMsg)
//            let bytes = MessageSerializer.serialize(msg)
//            try socket.send(Data(bytes))
//        }
////        let msg = Message
////        print("Received raw: \(received)")
////        print("received: \(try received.toString())")
//    }
//
//    let secReturn = request.headers["Sec-WebSocket-Key"]!.makeWebSocketSecKeyExchange()
////    let combined = inputKey + HashKey
////    let hashed = combined.toBase64()
////    HTTP/1.1 101 Switching Protocols
////    Upgrade: websocket
////    Connection: Upgrade
////    Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
////    Sec-WebSocket-Protocol: chat
//    var headers: Headers = [:]
//    headers["Connection"] = "Upgrade"
//    headers["Upgrade"] = "websocket"
//    // NOTE: Note that request has -Key, return has -Accept
//    headers["Sec-WebSocket-Accept"] = secReturn
////    headers["Sec-WebSocket-Version"] = "13"
//    // TODO: Read up and clarify this
////    headers["Sec-WebSocket-Protocol"] = request.headers["Sec-WebSocket-Protocol"]
//    var response = Response.init(status: .switchingProtocols, headers: headers)//, headers: Headers, cookies: Cookies, body: Stream)
//    response.webSocketConnection = socketHandler
//    print("\n\nReturning: \(response)\n\n")
//    return response
//}

app.get("socket") { request in
    print("Get socket: \(request)")
    func socketHandler(_ socket: Stream) throws {
        let ws = WebSock.init(socket)
        try ws.listen { sock, message in
            print("Got message: \(message)")
            let msg = WebSock.Message.respondToClient("Got it \(NSDate())")
            let bytes = MessageSerializer.serialize(msg)
            try sock.stream.send(Data(bytes))
        }
    }

    let secReturn = request.headers["Sec-WebSocket-Key"]!.makeWebSocketSecKeyExchange()
    //    let combined = inputKey + HashKey
    //    let hashed = combined.toBase64()
    //    HTTP/1.1 101 Switching Protocols
    //    Upgrade: websocket
    //    Connection: Upgrade
    //    Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
    //    Sec-WebSocket-Protocol: chat
    var headers: Headers = [:]
    headers["Connection"] = "Upgrade"
    headers["Upgrade"] = "websocket"
    // NOTE: Note that request has -Key, return has -Accept
    headers["Sec-WebSocket-Accept"] = secReturn
    //    headers["Sec-WebSocket-Version"] = "13"
    // TODO: Read up and clarify this
    //    headers["Sec-WebSocket-Protocol"] = request.headers["Sec-WebSocket-Protocol"]
    var response = Response.init(status: .switchingProtocols, headers: headers)//, headers: Headers, cookies: Cookies, body: Stream)
    response.webSocketConnection = socketHandler
    print("\n\nReturning: \(response)\n\n")
    return response
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
app.get("users") { req in
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

    return Response(status: .ok, html: response)
}

app.post("multipart-image") { request in
    guard let form = request.data.multipart else {
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
        headers["Content-Type"] = mediaType.type + "/" + mediaType.subtype
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
    guard let form = request.data.multipart else {
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
        headers["Content-Type"] = mediaType.type + "/" + mediaType.subtype
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
    guard let form = request.data.multipart, let multipart = form["options"] else {
        return "No form submited"
    }

    let selected = multipart.input ?? multipart.inputArray?.joined(separator: ", ")
    return "You have selected \"\(selected ?? "whoops!")\"\n"
}

app.post("multipart-print") { request in
    print(request.data)
    print(request.data.formEncoded)

    print(request.data["test"])
    print(request.data["test"].string)

    print(request.data.multipart?["test"])
    print(request.data.multipart?["test"]?.file)

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

//MARK: Async

app.get("async") { request in
    var response = Response(async: { stream in
        try stream.send("hello".data)
    })
    response.headers["Content-Type"] = "text/plain"
    response.headers["Transfer-Encoding"] = ""
    response.headers["Content-Length"] = 5.description
    return response
}

app.start()
