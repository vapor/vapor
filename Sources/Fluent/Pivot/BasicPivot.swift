import Async
import Foundation

/// A basic, free pivot implementation with fields for left
/// and right entities. Create your own pivot if you would
/// like to add additional fields.
public final class BasicPivot<L: Model, R: Model>: Pivot {
    /// See Pivot.Left
    public typealias Left = L

    /// See Pivot.Right
    public typealias Right = R

    /// See Model.id
    public var id: UUID?

    /// See Pivot.leftId
    public var leftID: Left.Identifier

    /// See Pivot.rightId
    public var rightID: Right.Identifier

    /// Create a new basic pivot from instances.
    public init(id: UUID? = nil, _ left: Left, _ right: Right) throws {
        self.id = id
        self.leftID = try left.requireID()
        self.rightID = try right.requireID()
    }

    /// Create a new basic pivot from IDs.
    public init(id: UUID? = nil, leftID: Left.Identifier, rightID: Right.Identifier) {
        self.id = id
        self.leftID = leftID
        self.rightID = rightID
    }
}

// MARK: Migration

public struct BasicPivotMigration<
    L: Model, R: Model, D: Database
>: Migration where D.Connection: QueryExecutor & SchemaExecutor {
    /// See Migration.Database
    public typealias Database = D

    /// This migration's corresponding pivot type.
    public typealias Pivot = BasicPivot<L, R>

    /// See Migration.prepare
    public static func prepare(on connection: Database.Connection) -> Future<Void> {
        return connection.create(Pivot.self) { builder in
            builder.id()

            let left = Field(name: "leftID", type: Pivot.Left.Identifier.fieldType)
            builder.schema.addFields.append(left)

            let right = Field(name: "rightID", type: Pivot.Right.Identifier.fieldType)
            builder.schema.addFields.append(right)
        }
    }

    /// See Migration.revert
    public static func revert(on connection: Database.Connection) -> Future<Void> {
        return connection.delete(Pivot.self)
    }
}

