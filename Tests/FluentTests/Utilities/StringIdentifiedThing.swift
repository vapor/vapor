//
//  StringIdentifiedThing.swift
//  Fluent
//
//  Created by Matias Piipari on 10/02/2017.
//
//

import Foundation

import Fluent

final class StringIdentifiedThing: Entity {
    static var idKey = "#id"
    let storage = Storage()

    init() {}
    
    init(row: Row) throws {
        id = try row.get(idKey)
    }
    
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(idKey, id)
        return row
    }
    
    static var idType: IdentifierType { return .custom("STRING(10)") }
    
    static func prepare(_ database: Database) throws {
        try database.create(self) { creator throws in
            creator.id()
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}
