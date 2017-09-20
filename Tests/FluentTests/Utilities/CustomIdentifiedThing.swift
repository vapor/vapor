//
//  CustomIdentifiedThing.swift
//  Fluent
//
//  Created by Matias Piipari on 10/02/2017.
//
//

import Foundation
import Fluent

final class CustomIdentifiedThing: Entity {
    let storage = Storage()
    static let idKey = "#id"
    init() {}
    
    init(row: Row) throws {}
    func makeRow() throws -> Row {
        return Row()
    }
    
    static var idType: IdentifierType { return .custom("INTEGER") }
    
    static func prepare(_ database: Database) throws {
        try database.create(self) { creator throws in
            creator.id()
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}
