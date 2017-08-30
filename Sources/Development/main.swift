import Core
import Dispatch
import HTTP
import Leaf
import Routing
import Service
import Vapor

extension View: ContentEncodable, ResponseRepresentable {
    public func encodeContent(to message: Message) throws {
        message.mediaType = .html
        message.body = Body(data)
    }
}


var services = Services.default()
try services.register(Leaf.Provider())

services.register { container in
    MiddlewareConfig([
        ErrorMiddleware.self
    ])
}

let app = Application(services: services)

let async = try app.make(AsyncRouter.self)
let sync = try app.make(SyncRouter.self)

let user = User(name: "Vapor", age: 3);
async.on(.get, to: "hello") { req in
    return Future<User>(user)
}

let hello = try Response(body: "Hello, world!")
sync.on(.get, to: "plaintext") { req in
    return hello
}

let view = try app.make(ViewRenderer.self)
async.on(.get, to: "leaf") { req -> Future<View> in
    user.child = User(name: "Leaf", age: 1)
    let promise = Promise(User.self)
    user.futureChild = promise.future

    try req.requireQueue().asyncAfter(deadline: .now() + 2) {
        let user = User(name: "unborn", age: -1)
        promise.complete(user)
    }
    
    return try view.make("/Users/tanner/Desktop/hello", context: user, for: req)
}

async.on(.get, to: "proxy") { req -> Future<Response> in
    let client = try app.make(Vapor.Client.self)
    let uri = URI(
        scheme: "http",
        userInfo: nil,
        hostname: "vapor.codes",
        port: 80,
        path: "/",
        query: nil,
        fragment: nil
    )

    let clientReq = Request(method: .get, uri: uri)
    clientReq.queue = req.queue

    return try client.respond(to: clientReq)
}

print("Starting server...")
try app.run()

