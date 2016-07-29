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
    public func makeJSON() -> JSON {
        return JSON([
            "name": name
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
