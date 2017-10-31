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
    public var leftID: Left.I

    /// See Pivot.rightId
    public var rightID: Right.I

    /// Create a new basic pivot from instances.
    public init(id: UUID? = nil, _ left: Left, _ right: Right) throws {
        self.id = id
        self.leftID = try left.requireId()
        self.rightID = try right.requireId()
    }

    /// Create a new basic pivot from IDs.
    public init(id: UUID? = nil, leftID: Left.I, rightID: Right.I) {
        self.id = id
        self.leftID = leftID
        self.rightID = rightID
    }
}

// MARK: Migration

// FIXME:
//extension BasicPivot: Migration {
//    /// See Migration.prepare
//    public static func prepare(_ database: MigrationExecutor) -> Future<Void> {
//        return database.create(self) { builder in
//            builder.id()
//
//            let left = Field(name: "leftID", type: Left.I.fieldType)
//            builder.schema.addFields.append(left)
//
//            let right = Field(name: "rightID", type: Right.I.fieldType)
//            builder.schema.addFields.append(right)
//        }
//    }
//
//    /// See Migration.revert
//    public static func revert(_ database: MigrationExecutor) -> Future<Void> {
//        return database.delete(self)
//    }
//}

