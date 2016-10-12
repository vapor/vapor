import Vapor

final class User: Model {
    var id: Node?
    var name: String

    init(name: String) {
        self.name = name
    }

    init(node: Node, in context: Context) throws {
        self.name = try node.extract("name")
    }

    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "name": name
        ])
    }

    static func prepare(_ database: Database) throws {

    }

    static func revert(_ database: Database) throws {

    }
}

extension User: CustomStringConvertible {
    var description: String {
        return "[User: \(name)]"
    }
}

extension User: StringInitializable {
    convenience init?(from string: String) throws {
        self.init(name: string)
    }
}
