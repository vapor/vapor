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

let beta: DatabaseIdentifier<SQLiteDatabase> = .init("beta")

extension DatabaseIdentifier {
    static var beta: DatabaseIdentifier<SQLiteDatabase> {
        return .init("beta")
    }

    static var alpha: DatabaseIdentifier<SQLiteDatabase> {
        return .init("alpha")
    }
}




var services = Services.default()

services.register(FluentMiddleware())

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

var middlewareConfig = MiddlewareConfig()
// middlewareConfig.use(FluentMiddleware.self)
middlewareConfig.use(ErrorMiddleware.self)
services.register(middlewareConfig)

let app = try Application(services: services)

let foo = try app.withDatabase(.alpha) { alpha in
    return try alpha.query(string: "select sqlite_version();").all()
}.blockingAwait()
print(foo)

let router = try app.make(Router.self)

router.get("hello") { req -> [User] in
    let user = User(name: "Vapor", age: 3);
    return [user]
}


struct LoginRequest: Content {
    var email: String
    var password: String
}

let helloRes = try! Response(headers: [
    .contentType: "text/plain; charset=utf-8"
], body: "Hello, world!")
router.grouped(DateMiddleware()).get("plaintext") { req in
    return helloRes
}

let view = try app.make(ViewRenderer.self)


router.post("login") { req -> Response in
    let loginRequest = try req.content(LoginRequest.self)

    print(loginRequest.email) // user@vapor.codes
    print(loginRequest.password) // don't look!

    return Response(status: .ok)
}

router.get("leaf") { req -> Future<View> in
    let promise = Promise(User.self)
    // user.futureChild = promise.future

    req.eventLoop.queue.asyncAfter(deadline: .now() + 2) {
        let user = User(name: "unborn", age: -1)
        promise.complete(user)
    }

    let user = User(name: "Vapor", age: 3);
    return try view.make("/Users/tanner/Desktop/hello", context: user, on: req)
}

final class FooController {
    func foo(_ req: Request) -> Future<Response> {
        return req.withDatabase(.alpha) { db in
            return Response(status: .ok)
        }
    }
}

let controller = FooController()
router.post("login", use: controller.foo)

final class Message: Model {
    static let keyFieldMap: KeyFieldMap = [
        key(\.id): field("id"),
        key(\.text): field("text"),
        key(\.time): field("customtime"),
    ]

    static let database: DatabaseIdentifier<SQLiteDatabase> = .beta
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
        let container = try Message.decodingContainer(for: decoder)
        id = try container.decode(key: \Message.id)
        text = try container.decode(key: \Message.text)
        time = try container.decode(key: \Message.time)
    }

    func encode(to encoder: Encoder) throws {
        var container = encodingContainer(for: encoder)
        try container.encode(key: \Message.id)
        try container.encode(key: \Message.text)
        try container.encode(key: \Message.time)
    }
}

router.get("userview") { req -> Future<View> in
    let user = User.query(on: req).first()

    return try view.make("/Users/tanner/Desktop/hello", context: [
        "user": user
    ], on: req)
}

router.post("users") { req -> Future<User> in
    let user = try JSONDecoder().decode(User.self, from: req.body.data)
    return user.save(on: req).map { user }
}

router.get("builder") { req -> Future<[User]> in
    return try User.query(on: req).filter(\User.name == "Bob").all()
}


router.get("transaction") { req -> Future<String> in
    return req.withDatabase(.beta) { db in
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

router.get("pets", Pet.parameter, "toys") { req in
    return try req.parameters.next(Pet.self).then { pet in
        return try pet.toys.query(on: req).all()
    }
}

router.get("string", String.parameter) { req -> String in
    return try req.parameters.next(String.self)
}

router.get("users") { req -> Future<Response> in
    let marie = User(name: "Marie Curie", age: 66)
    let charles = User(name: "Charles Darwin", age: 73)

    return [
        marie.save(on: req),
        charles.save(on: req)
    ].map {
        return Response(status: .created)
    }
}

router.get("hello") { req in
    return try User.query(on: req).filter(\User.age > 50).all()
}

router.get("first") { req -> Future<User> in
    return try User.query(on: req).filter(\User.name == "Vapor").first().map { user in
        guard let user = user else {
            throw Abort(.notFound, reason: "Could not find user.")
        }

        return user
    }
}

router.get("asyncusers") { req -> Future<User> in
    let user = User(name: "Bob", age: 1)
    return req.withDatabase(.beta) { db -> Future<User> in
        return user.save(on: db).map {
            return user
        }
    }
}

print("Starting server...")
try app.run()

