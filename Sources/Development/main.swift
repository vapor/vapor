import Core
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
    MiddlewareConfig([])
}

let app = Application(services: services)

let async = try app.make(AsyncRouter.self)
let sync = try app.make(SyncRouter.self)

async.on(.get, to: "hello") { req -> Future<User> in
    let user = User(name: "Vapor", age: 3)
    return .init(user)
}

let hello = try Response(body: "Hello, world!")
let fut = Future(hello as ResponseRepresentable)
sync.on(.get, to: "plaintext") { req in
    return hello
}

let view = try app.make(ViewRenderer.self)
async.on(.get, to: "welcome") { req -> Future<View> in
    return try view.make("hello", context: "foo")
}

print("Starting server...")
try app.run()


