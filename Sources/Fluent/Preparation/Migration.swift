final class Migration: Entity {
    static var entity = migrationEntityName
    let storage = Storage()
    var name: String
    var batch: Int

    init(name: String, batch: Int) {
        self.name = name
        self.batch = batch
    }

    init(row: Row) throws {
        name = try row.get("name")
        batch = try row.get("batch")
        id = try row.get(idKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set("name", name)
        try row.set("batch", batch)
        return row
    }
}

extension Migration: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string("name")
            builder.int("batch")
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

extension Migration: Timestampable {}

public var migrationEntityName: String = "fluent"
