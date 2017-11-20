import FluentSQLite
import Foundation
import Vapor

final class Pet: Model {

    typealias Database = SQLiteDatabase
    typealias ID = UUID

    static let keyFieldMap: KeyFieldMap = [
        key(\.id): field("id"),
        key(\.name): field("name"),
        key(\.ownerID): field("ownerID")
    ]

    static let dbID: DatabaseIdentifier<SQLiteDatabase> = .beta
    static let idKey = \Pet.id

    var id: UUID?
    var name: String
    var ownerID: User.ID

    init(id: ID? = nil, name: String, ownerID: User.ID) {
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

extension Pet: Parameter {}

extension Pet: Migration {
    static func prepare(on connection: SQLiteConnection) -> Future<Void> {
        return connection.create(self) { schema in
            try schema.field(for: \.id)
            try schema.field(for: \.name)
            try schema.field(for: \.ownerID)
        }
    }
    
    static func revert(on connection: SQLiteConnection) -> Future<Void> {
        return connection.delete(self)
    }
    
}
