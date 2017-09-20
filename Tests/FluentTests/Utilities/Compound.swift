import Fluent

final class Compound: Entity {
    var name: String
    let storage = Storage()

    init(name: String) {
        self.name = name
    }

    init(row: Row) throws {
        name = try row.get("name")
        id = try row.get(idKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(idKey, id)
        try row.set("name", name)
        return row
    }
}

extension Compound: Preparation {
    static func prepare(_ database: Fluent.Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string("name")
        }
    }
    static func revert(_ database: Fluent.Database) throws {
        try database.delete(self)
    }
}
