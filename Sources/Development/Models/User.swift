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
        return children(foreignField: User.field("ownerID"))
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



