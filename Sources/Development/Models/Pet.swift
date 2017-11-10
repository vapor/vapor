import Async
import HTTP
import Fluent
import Foundation
import Routing
import SQLite

final class Pet: Model {
    typealias Database = SQLiteDatabase
    typealias ID = UUID

    static let keyFieldMap: KeyFieldMap = [
        key(\.id): field("id"),
        key(\.name): field("name"),
        key(\.ownerID): field("ownerID")
    ]

    static let idKey = \Pet.id

    var id: UUID?
    var name: String
    var ownerID: UUID

    init(id: ID? = nil, name: String, ownerID: UUID) {
        self.id = id
        self.name = name
        self.ownerID = ownerID
    }

    var owner: Parent<Pet, User> {
        return parent(\.ownerID)
    }

    var toys: Siblings<Pet, Toy, PetToyPivot> {
        return siblings()
    }
}

// FIXME: find way to include this in fluent
extension Pet: Parameter {
    static var uniqueSlug: String {
        return "pet"
    }

    static func make(for parameter: String, in req: Request) throws -> Future<Pet> {
        guard let uuid = UUID(uuidString: parameter) else {
            throw "not a uuid"
        }

        return req.database(.beta) { conn in
            return Pet.find(uuid, on: conn).map { pet in
                guard let pet = pet else {
                    throw "no pet w/ that id was found"
                }

                return pet
            }
        }
    }
}


extension Pet: Migration {
    static func prepare(on connection: SQLiteConnection) -> Future<Void> {
        return connection.create(self) { schema in
            try schema.id()
            try schema.field(for: \.name)
            try schema.field(for: \.ownerID)
        }
    }
    
    static func revert(on connection: SQLiteConnection) -> Future<Void> {
        return connection.delete(self)
    }
    
}
