//import FluentSQLite
//import Foundation
//import Vapor
//
//final class Pet: Model {
//    typealias Database = SQLiteDatabase
//    static let idKey = \Pet.id
//
//    var id: UUID?
//    var name: String
//    var ownerID: User.ID
//
//    init(id: UUID? = nil, name: String, ownerID: User.ID) {
//        self.id = id
//        self.name = name
//        self.ownerID = ownerID
//    }
//
//    var owner: Parent<Pet, User> {
//        return parent(\.ownerID)
//    }
//
//    var toys: Siblings<Pet, Toy, PetToyPivot> {
//        return siblings()
//    }
//}
//
//extension Pet: Parameter {}
//
//extension Pet: Migration {
//    static func prepare(on connection: SQLiteConnection) -> Future<Void> {
//        return connection.create(self) { schema in
//            try schema.field(for: \.id)
//            try schema.field(for: \.name)
//            try schema.field(for: \.ownerID)
//        }
//    }
//    
//    static func revert(on connection: SQLiteConnection) -> Future<Void> {
//        return connection.delete(self)
//    }
//    
//}

