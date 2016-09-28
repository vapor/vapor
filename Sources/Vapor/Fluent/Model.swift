import JSON
import Fluent
import TypeSafeRouting
import HTTP

@_exported import class Fluent.Database

public protocol Model: Entity, JSONRepresentable, StringInitializable, ResponseRepresentable { }

extension Model {
    public func makeResponse() throws -> Response {
        return try makeJSON().makeResponse()
    }
}

// MARK: JSONRepresentable

extension Model {
    public func makeJSON() throws -> JSON {
        let node = try makeNode()
        return try JSON(node: node)
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
