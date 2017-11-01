import Foundation
import Async
import HTTP
import Leaf
import Vapor
import Fluent
import SQLite


struct TestSiblings: Migration {
    typealias Database = SQLiteDatabase

    static func prepare(on connection: SQLiteConnection) -> Future<Void> {
        let owner = User(name: "Tanner", age: 23)
        return owner.save(on: connection).flatMap {
            let pet = try Pet(name: "Ziz", ownerID: owner.requireID())
            let toy = Toy(name: "Rubber Band")

            return [
                pet.save(on: connection),
                toy.save(on: connection)
            ].flatten().flatMap {
                let pivot = try BasicPivot<Toy, Pet>(toy, pet)
                return pivot.save(on: connection)
            }
        }
    }

    static func revert(on connection: SQLiteConnection) -> Future<Void> {
        return Future(())
    }
}

import Routing

extension Pet: Parameter {
    static var uniqueSlug: String {
        return "pet"
    }

    static func make(for parameter: String, in request: Request) throws -> Future<Pet> {
        guard let uuid = UUID(uuidString: parameter) else {
            throw "not a uuid"
        }

        return Pet.find(uuid, on: request.database(.beta)).map { pet in
            guard let pet = pet else {
                throw "invalid pet id"
            }

            return pet
        }
    }
}

final class Pet: Model {
    var id: UUID?
    var name: String
    var ownerID: UUID

    init(name: String, ownerID: UUID) {
        self.name = name
        self.ownerID = ownerID
    }

    var owner: Parent<Pet, User> {
        return parent(idKey: \Pet.ownerID)
    }

    var toys: Siblings<Pet, Toy, BasicPivot<Toy, Pet>> {
        return siblings(fromForeignIDKey: "rightID", toForeignIDKey: "leftID")
    }
}

extension Pet: Migration {
    typealias Database = SQLiteDatabase

    static func prepare(on connection: SQLiteConnection) -> Future<Void> {
        return connection.create(self) { builder in
            builder.id()
            builder.string("name")
            builder.data("ownerID", length: 16)
        }
    }

    static func revert(on connection: SQLiteConnection) -> Future<Void> {
        return connection.delete(self)
    }
}

final class Toy: Model {
    var id: UUID?
    var name: String

    init(name: String) {
        self.name = name
    }

    var pets: Siblings<Toy, Pet, BasicPivot<Toy, Pet>> {
        return siblings()
    }
}

extension Toy: Migration {
    typealias Database = SQLiteDatabase

    static func prepare(on connection: SQLiteConnection) -> Future<Void> {
        return connection.create(self) { builder in
            builder.id()
            builder.string("name")
        }
    }

    static func revert(on connection: SQLiteConnection) -> Future<Void> {
        return connection.delete(self)
    }
}

final class User: Model, ResponseRepresentable {
    var id: UUID?
    var name: String
    var age: Int
//    var child: User?
//    var futureChild: Future<User>?
    
    func makeResponse(for request: Request) throws -> Response {
        let body = try  Body(JSONEncoder().encode(self))
        
        return Response(body: body)
    }

    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }

    var pets: Children<User, Pet> {
        return children(foreignKey: "ownerID")
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
    typealias Database = SQLiteDatabase

    static func prepare(on conn: SQLiteConnection) -> Future<Void> {
        return conn.create(User.self) { user in
            user.data("id", length: 16, isIdentifier: true)
            user.string("name")
            user.int("age")
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



