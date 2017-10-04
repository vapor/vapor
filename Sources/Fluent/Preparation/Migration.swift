final class Migration: Model {
    static var entity = migrationEntityName
    var name: String
    var batch: Int
    let storage = Storage()

    init(name: String, batch: Int) {
        self.name = name
        self.batch = batch
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
