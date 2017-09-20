import Fluent

final class Group: Entity {
    let storage = Storage()
    init(row: Row) throws {}
    func makeRow() -> Row { return .null }
}

extension Group: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create(self) { groups in
            groups.id()
        }
    }
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}
