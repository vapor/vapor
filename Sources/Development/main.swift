import Async
import Core
import Dispatch
import Fluent
import FluentSQLite
import Foundation
import HTTP
import Leaf
import Routing
import Service
import SQLite
import Vapor

extension DatabaseIdentifier {
    static var beta: DatabaseIdentifier<SQLiteDatabase> {
        return .init("beta")
    }

    static var alpha: DatabaseIdentifier<SQLiteDatabase> {
        return .init("alpha")
    }
}

var services = Services.default()

services.register(SQLiteStorage.file(path: "/tmp/alpha.sqlite"))
try services.register(LeafProvider())
try services.register(FluentProvider())
try services.register(SQLiteProvider())

var databaseConfig = DatabaseConfig()
databaseConfig.add(database: SQLiteDatabase.self, as: .alpha)
databaseConfig.add(
    database: SQLiteDatabase(storage: .file(path: "/tmp/beta.sqlite")),
    as: .beta
)
databaseConfig.enableLogging(on: .beta)
services.register(databaseConfig)


var migrationConfig = MigrationConfig()
migrationConfig.add(migration: User.self, database: .beta)
migrationConfig.add(migration: AddUsers.self, database: .beta)
migrationConfig.add(migration: Pet.self, database: .beta)
migrationConfig.add(migration: Toy.self, database: .beta)
migrationConfig.add(migration: PetToyPivot.self, database: .beta)
migrationConfig.add(migration: TestSiblings.self, database: .beta)
services.register(migrationConfig)

services.register(
    MiddlewareConfig([
        ErrorMiddleware.self
    ])
)

let app = try Application(services: services)

let router = try app.make(Router.self)

let user = User(name: "Vapor", age: 3);
router.get("hello") { req -> Response in
    return try user.makeResponse(for: req)
}


let helloRes = try! Response(headers: [
    .contentType: "text/plain; charset=utf-8"
], body: "Hello, world!")
router.grouped(DateMiddleware()).get("plaintext") { req in
    return helloRes
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
    static let keyFieldMap = [
        key(\.id): field("id"),
        key(\.text): field("text"),
        key(\.time): field("customtime"),
    ]

    static let idKey = \Message.id

    var id: String?
    var text: String
    var time: Int

    init(id: String? = nil, text: String, time: Int) {
        self.id = id
        self.text = text
        self.time = time
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: QueryField.self)
        id = try container.decode(forKey: \Message.id)
        text = try container.decode(forKey: \Message.text)
        time = try container.decode(forKey: \Message.time)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: QueryField.self)
        try container.encode(id, forKey: \Message.id)
        try container.encode(text, forKey: \Message.text)
        try container.encode(time, forKey: \Message.time)
    }
}

router.get("userview") { req -> Future<View> in
    return req.database(.beta) { db in
        let user = db.query(User.self).first()

        return try view.make("/Users/tanner/Desktop/hello", context: [
            "user": user
        ], for: req)
    }
}

router.post("users") { req -> Future<User> in
    let user = try JSONDecoder().decode(User.self, from: req.body.data)
    return req.database(.beta) { db in
        return user.save(on: db).map { user }
    }
}

router.get("builder") { req -> Future<[User]> in
    return req.database(.beta) { db in
        return db.query(User.self).filter(\User.name == "Bob").all()
    }
}

router.get("transaction") { req -> Future<String> in
    return req.database(.beta) { db in
        db.transaction { db in
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
}

router.get("pets", Pet.parameter, "toys") { req -> Future<[Toy]> in
    return req.parameters.next(Pet.self).then { pet in
        return req.database(.beta) { db in
            return try pet.toys.query(on: db).all()
        }
    }
}

router.get("users") { req in
    return req.database(.beta) { db in
        return db.query(User.self).all()
    }
}

print("Starting server...")
try app.run()

