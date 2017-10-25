import Foundation
import Async
import HTTP
import Leaf
import Vapor
import Fluent

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
    static func prepare(_ database: DatabaseConnection) -> Future<Void> {
        return database.create(User.self) { user in
            user.data("id", length: 16, isIdentifier: true)
            user.string("name")
            user.int("age")
        }
    }

    static func revert(_ database: DatabaseConnection) -> Future<Void> {
        return database.delete(User.self)
    }
}

struct AddUsers: Migration {
    static func prepare(_ db: DatabaseConnection) -> Future<Void> {
        var bob = User(name: "Bob", age: 42)
        var vapor = User(name: "Vapor", age: 3)

        return [
            bob.save(to: db),
            vapor.save(to: db)
        ].flatten()
    }

    static func revert(_ database: DatabaseConnection) -> Future<Void> {
        return Future(())
    }
}



