import Foundation
import Async
import HTTP
import Leaf
import Vapor
import Fluent
import SQLite

import Foundation

final class TestUser: Codable {
    var id: UUID?
    var name: String
    var age: Int
}

extension TestUser: Model {
    /// See Model.Database
    typealias Database = SQLiteDatabase

    /// See Model.ID
    typealias ID = UUID

    /// See Model.idKey
    static var idKey: IDKey {
        return \.id
    }

    /// See Model.keyFieldMap
    static var keyFieldMap: KeyFieldMap {
        return [
            key(\.id): field("id"),
            key(\.name): field("name"),
            key(\.age): field("age"),
        ]
    }
}

extension TestUser: Migration {
    /// See Migration.prepare
    static func prepare(on connection: SQLiteConnection) -> Future<Void> {
        return connection.create(self) { builder in
            try builder.field(for: \.id)
            try builder.field(for: \.name)
            try builder.field(for: \.age)
        }
    }

    /// See Migration.revert
    static func revert(on connection: SQLiteConnection) -> Future<Void> {
        return connection.delete(self)
    }
}


struct TestSiblings: Migration {
    typealias Database = SQLiteDatabase

    static func prepare(on connection: SQLiteConnection) -> Future<Void> {
        let owner = User(name: "Tanner", age: 23)
        return owner.save(on: connection).then {
            let pet = try Pet(name: "Ziz", ownerID: owner.requireID())
            let toy = Toy(name: "Rubber Band")

            return [
                pet.save(on: connection),
                toy.save(on: connection)
            ].flatten().then {
                return pet.toys.attach(toy, on: connection)
            }
        }
    }

    static func revert(on connection: SQLiteConnection) -> Future<Void> {
        return Future(())
    }
}

extension ResponseRepresentable where Self: Content {
    func makeResponse(for request: Request) throws -> Response {
        let res = Response(status: .ok)
        try res.content(self)
        return res
    }
}

final class User: Model, ResponseRepresentable, Content {
    static let defaultMediaType: MediaType = .json

    typealias Database = SQLiteDatabase
    typealias ID = UUID

    static let keyFieldMap: KeyFieldMap = [
        key(\.id): field("id"),
        key(\.name): field("name"),
        key(\.age): field("age"),
    ]

    static var idKey: IDKey {
        return \.id
    }

    var id: UUID?
    var name: String
    var age: Double
//    var child: User?
//    var futureChild: Future<User>?

    init(name: String, age: Double) {
        self.name = name
        self.age = age
    }

    var pets: Children<User, Pet> {
        return children(\.ownerID)
    }
}


extension Future: Codable {
    public func encode(to encoder: Encoder) throws {
        guard var single = encoder.singleValueContainer() as? FutureEncoder else {
            throw "need a future encoder"
        }

        try single.encode(self)
    }

    public convenience init(from decoder: Decoder) throws {
        fatalError("blah")
    }
}

extension Array: ResponseRepresentable {
    public func makeResponse(for request: Request) throws -> Response {
        let body = try Body(JSONEncoder().encode(self))
        let res = Response(body: body)
        res.mediaType = .json
        return res
    }
}

extension User: Migration {
    static func prepare(on conn: SQLiteConnection) -> Future<Void> {
        return conn.create(User.self) { user in
            try user.field(for: \.id)
            try user.field(for: \.name)
            try user.field(for: \.age)
        }
    }

    static func revert(on conn: SQLiteConnection) -> Future<Void> {
        return conn.delete(User.self)
    }
}

struct AddUsers: Migration {
    typealias Database = SQLiteDatabase
    
    static func prepare(on conn: SQLiteConnection) -> Future<Void> {
        let bob = User(name: "Bob", age: 42)
        let vapor = User(name: "Vapor", age: 3)

        return [
            bob.save(on: conn),
            vapor.save(on: conn)
        ].flatten()
    }

    static func revert(on conn: SQLiteConnection) -> Future<Void> {
        return Future(())
    }
}



