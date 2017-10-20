import Foundation
import Async
import HTTP
import Leaf
import Vapor
import Fluent

final class User: Codable, ResponseRepresentable {
    var name: String
    var age: Int
    var child: User?
    var futureChild: Future<User>?
    
    func makeResponse(for request: Request) throws -> Response {
        let body = Body(try JSONEncoder().encode(self))
        
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

extension User: Migration {
    static func prepare(database: Database) -> Future<Void> {
        // FIXME: we should probably get a database connection passed
        database.makeConnection(on: .global()).
    }

    static func revert(database: Database) -> Future<Void> {
        <#code#>
    }
}
