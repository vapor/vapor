import Fluent

final class Atom: Entity {
    var name: String
    var groupId: Identifier
    let storage = Storage()

    init(name: String, id: Identifier? = nil) {
        self.name = name
        self.groupId = 0
        self.id = id
    }

    init(row: Row) throws {
        name = try row.get("name")
        groupId = try row.get("group_id")
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(idKey, id)
        try row.set("name", name)
        try row.set("group_id", groupId)
        return row
    }

    var compounds: Siblings<Atom, Compound, Pivot<Atom, Compound>> {
        return siblings()
    }

    func group() throws -> Parent<Atom, Group> {
        return parent(id: groupId)
    }

    func protons() throws -> Children<Atom, Proton> {
        return children()
    }

    func nucleus() throws -> Nucleus? {
        return try children().first()
    }

    // MARK: Callbacks

    func willCreate() {
        print("Atom will create.")
    }

    func didCreate() {
        print("Atom did create.")
    }

    func willUpdate() {
        print("Atom will update.")
    }

    func didUpdate() {
        print("Atom did update.")
    }

    func willDelete() {
        print("Atom will delete.")
    }

    func didDelete() {
        print("Atom did delete.")
    }
}

extension Atom: Preparation {
    static func prepare(_ database: Fluent.Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string("name")
            builder.int("group_id")
        }
    }
    static func revert(_ database: Fluent.Database) throws {
        try database.delete(self)
    }
}
