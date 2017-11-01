import Async
import HTTP
import Fluent
import Foundation
import Routing
import SQLite

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

    var toys: Siblings<Pet, Toy, PetToyPivot> {
        return siblings()
    }
}

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
