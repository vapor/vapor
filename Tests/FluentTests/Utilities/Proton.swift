import Fluent

final class Proton: Entity {
    let storage = Storage()
    init(row: Row) throws {}
    func makeRow() -> Row { return .null }
}

extension Proton: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create(self) { protons in
            protons.id()
            protons.foreignId(for: Atom.self)
        }
    }
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}
