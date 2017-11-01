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

let router = try app.make(Router.self)

let user = User(name: "Vapor", age: 3);

router.get("hello") { req in
    return Future<User>(user)
}

extension Worker {
    var response: Response {
        if let response = self.extend["response"] as? Response {
            return response
        }

        let response = try! Response(headers: [
            .contentType: "text/plain; charset=utf-8"
        ], body: "Hello, world!")

        self.extend["response"] = response

        return response
    }
}

router.grouped(DateMiddleware()).get("plaintext") { req in
    return try req.requireWorker().response
}

let view = try app.make(ViewRenderer.self)

router.get("leaf") { req -> Future<View> in
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

final class Message: Model {
    var id: String?
    var text: String
    var time: Int

    init(id: String? = nil, text: String, time: Int) {
        self.id = id
        self.text = text
        self.time = time
    }
}

router.get("userview") { req -> Future<View> in
    let user = req.database().query(User.self).first()
    return try view.make("/Users/tanner/Desktop/hello", context: [
        "user": user
    ], for: req)
}

router.post("users") { req -> Future<User> in
    let user = try JSONDecoder().decode(User.self, from: req.body.data)
    return user.save(on: req.database(id: .memory)).map { user }
}

router.get("transaction") { req -> Future<String> in
    return req.database(id: .memory).transaction { db in
        let user = User(name: "NO SAVE", age: 500)
        let message = Message(id: nil, text: "asdf", time: 42)

        return [
            user.save(on: db),
            message.save(on: db)
        ].flatten()
    }.map {
        return "Done"
    }
}

router.get("users") { req in
    return req.database(id: .memory).query(User.self).all()
}

router.get("sqlite") { req -> Future<String> in
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

