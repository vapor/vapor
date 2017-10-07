import Async
import Core
import Dispatch
import Fluent
import Foundation
import HTTP
import Leaf
import Routing
import Service
import SQLite
import Vapor

var services = Services.default()

services.register(SQLiteStorage.file(path: "/tmp/db.sqlite"))
try services.register(LeafProvider())
try services.register(FluentProvider())

services.register(
    MiddlewareConfig([
        DatabaseMiddleware.self,
        ErrorMiddleware.self
    ])
)

let app = Application(services: services)

let async = try app.make(AsyncRouter.self)
let sync = try app.make(SyncRouter.self)

let user = User(name: "Vapor", age: 3);
async.get("hello") { req in
    return Future<User>(user)
}

let hello = try Response(body: "Hello, world!")
sync.get("plaintext") { req in
    return hello
}

let view = try app.make(ViewRenderer.self)
async.get("leaf") { req -> Future<View> in
    user.child = User(name: "Leaf", age: 1)
    let promise = Promise(User.self)
    user.futureChild = promise.future

    try req.requireWorker().queue.asyncAfter(deadline: .now() + 2) {
        let user = User(name: "unborn", age: -1)
        promise.complete(user)
    }
    
    return try view.make("/Users/tanner/Desktop/hello", context: user, for: req)
}

extension String: ResponseRepresentable {
    public func makeResponse(for req: Request) throws -> Response {
        let data = self.data(using: .utf8)!
        return Response(status: .ok, headers: ["Content-Type": "text/plain"], body: Body(data))
    }
}

struct Message: Model {
    var id: String?
    var text: String
    var time: Int
    let storage = Storage()
}

async.get("fluent") { req -> Future<String> in
    let promise = Promise(String.self)

    let query = try req.makeQuery(for: Message.self)
        .filter("text" == "hello")
    
    // FIXME: generate sql
    // query.sql = "SELECT * FROM `messages`;"

    query.data = Message(id: "UUID:5", text: "asdf", time: 123)

    query.all().then { messages in
        var data = ""
        for message in messages {
            data += "\(message.id!): \(message.text) @ \(message.time)\n"
        }
        promise.complete(data)
    }.catch { err in
        promise.fail(err)
    }

    return promise.future
}

print("Starting server...")
try app.run()

