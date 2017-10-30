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

extension DatabaseIdentifier {
    static var memory: DatabaseIdentifier {
        return .init("memory")
    }
}

var services = Services.default()

services.register(SQLiteStorage.file(path: "/tmp/db.sqlite"))
try services.register(LeafProvider())
try services.register(FluentProvider())

var databaseConfig = DatabaseConfig()
databaseConfig.add(database: SQLiteDatabase.self)
databaseConfig.add(
    database: SQLiteDatabase(storage: .file(path: "/tmp/memory.sqlite")),
    as: .memory
)
services.register(databaseConfig)


var migrationConfig = MigrationConfig()
migrationConfig.add(migration: User.self, database: .memory)
migrationConfig.add(migration: AddUsers.self, database: .memory)
services.register(migrationConfig)

services.register(
    MiddlewareConfig([
        DatabaseMiddleware.self,
        ErrorMiddleware.self
    ])
)

let app = try Application(services: services)

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
    // user.child = User(name: "Leaf", age: 1)
    let promise = Promise(User.self)
    // user.futureChild = promise.future

    req.eventLoop.queue.asyncAfter(deadline: .now() + 2) {
        let user = User(name: "unborn", age: -1)
        promise.complete(user)
    }
    
    return try view.make("/Users/tanner/Desktop/hello", context: user, for: req)
}

extension String: ResponseRepresentable {
    public func makeResponse(for req: Request) throws -> Response {
        let data = self.data(using: .utf8)!
        return Response(status: .ok, headers: [.contentType: "text/plain"], body: Body(data))
    }
}

struct Message: Model {
    var id: String?
    var text: String
    var time: Int
}

async.get("userview") { req -> Future<View> in
    let user = req.database().query(User.self).first()
    return try view.make("/Users/tanner/Desktop/hello", context: [
        "user": user
    ], for: req)
}

async.post("users") { req -> Future<User> in
    var user = try JSONDecoder().decode(User.self, from: req.body.data)
    return user.save(to: req.database(id: .memory)).map { user }
}

async.get("transaction") { req -> Future<String> in
    return req.database(id: .memory).transaction { db in
        var user = User(name: "NO SAVE", age: 500)
        var message = Message(id: nil, text: "asdf", time: 42)

        return [
            user.save(to: db),
            message.save(to: db)
        ].flatten()
    }.map {
        return "Done"
    }
}

async.get("users") { req in
    return req.database(id: .memory).query(User.self).all()
}

async.get("fluent") { req -> Future<String> in
    let promise = Promise(String.self)

//    try req.query(Message.self)
//        .filter("text" == "hello")
//        .count().then { count in
//            print(count)
//    }

    let query = req.database().query(Message.self)

    // query.data = Message(id: "UUID:5", text: "asdf", time: 123)

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

