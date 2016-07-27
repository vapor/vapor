import JSON
import Fluent

public protocol Model: Entity, JSONRepresentable, StringInitializable { }

// MARK: JSONRepresentable

extension Model {
    public func makeJSON() throws -> JSON {
        let node = try makeNode()
        return try JSON(node)
    }
}

// MARK: StringInitializable

extension Model {
    public init?(from string: String) throws {
        if let model = try Self.find(string) {
            self = model
        } else {
            return nil
        }
    }
}
