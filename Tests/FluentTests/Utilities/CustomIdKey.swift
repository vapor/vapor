import Fluent

final class CustomIdKey: Entity {
    let storage = Storage()
    
    static var idKey: String {
        return "custom_id"
    }
    
    static func prepare(_ database: Fluent.Database) throws {
        try database.create(self) { builder in
            builder.foreignId(for: CustomIdKey.self)
            builder.string("label")
        }
    }
    static func revert(_ database: Fluent.Database) throws {
        try database.delete(self)
    }
    
    var label: String
    
    init(id: Identifier?, label: String) {
        self.label = label
        self.id = id
    }
    
    init(row: Row) throws {
        label = try row.get("label")
    }
    
    func makeRow() throws -> Row {
        var row = Row()
        try row.set("label", label)
        return row
    }
}
