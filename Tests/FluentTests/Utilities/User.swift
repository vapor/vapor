import Fluent

final class User: Entity {
    let storage = Storage()
    
    static func prepare(_ database: Fluent.Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string("name")
            builder.string("email")
        }
    }
    static func revert(_ database: Fluent.Database) throws {
        try database.delete(self)
    }

    var name: String
    var email: String

    init(id: Identifier?, name: String, email: String) {
        self.name = name
        self.email = email
        self.id = id
    }

    init(row: Row) throws {
        name = try row.get("name")
        email = try row.get("email")
        id = try row.get(idKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(idKey, id)
        try row.set("name", name)
        try row.set("email", email)
        return row
    }
}

extension User: Equatable {
    static func ==(lhs: User, rhs: User) -> Bool {
        return lhs.name == rhs.name
    }
}
