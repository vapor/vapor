import Fluent

final class Nucleus: Entity {
    let storage = Storage()
    static var entity = "nuclei"

    init(row: Row) { }
    func makeRow() -> Row { return .null }
}

extension Nucleus: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create(self) { nuclei in
            nuclei.id()
            nuclei.foreignId(for: Atom.self)
        }
    }
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}
