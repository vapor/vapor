import Node
import JSON
import Vapor

final class User {
    var name: String

    init(name: String) {
        self.name = name
    }
}

extension User: JSONRepresentable {
    public func makeJSON() throws -> JSON {
        return try makeNode().converted()
    }

    func makeNode() throws -> Node {
        return try Node([
            "name": "\(name)"
        ])
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
