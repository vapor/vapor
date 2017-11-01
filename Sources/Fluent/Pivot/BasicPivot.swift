import Async
import Foundation

/// A basic, free pivot implementation with fields for left
/// and right entities. Create your own pivot if you would
/// like to add additional fields.
public final class BasicPivot<L: Model, R: Model>: ModifiablePivot {
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

    /// Pivot keys for codable.
    typealias PivotKeys = BasicPivotKeys<Left, Right>

    /// Create a new basic pivot from instances.
    public init(id: UUID?, _ left: Left, _ right: Right) throws {
        self.id = id
        self.leftID = try left.requireID()
        self.rightID = try right.requireID()
    }

    /// See ModifiablePivot.init
    public convenience init(_ left: L, _ right: R) throws {
        try self.init(id: nil, left, right)
    }

    /// Create a new basic pivot from IDs.
    public init(id: UUID? = nil, leftID: Left.Identifier, rightID: Right.Identifier) {
        self.id = id
        self.leftID = leftID
        self.rightID = rightID
    }

    /// See Decodable.init
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: PivotKeys.self)
        try self.init(
            id: values.decode(UUID.self, forKey: .idKey),
            leftID: values.decode(Left.Identifier.self, forKey: .leftIDKey),
            rightID: values.decode(Right.Identifier.self, forKey: .rightIDKey)
        )
    }

    /// See Encodable.encode
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: PivotKeys.self)
        try values.encode(id, forKey: .idKey)
        try values.encode(id, forKey: .leftIDKey)
        try values.encode(id, forKey: .rightIDKey)
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

            let left = Field(name: Pivot.Left.foreignIDKey, type: Pivot.Left.Identifier.fieldType)
            builder.schema.addFields.append(left)

            let right = Field(name: Pivot.Right.foreignIDKey, type: Pivot.Right.Identifier.fieldType)
            builder.schema.addFields.append(right)
        }
    }

    /// See Migration.revert
    public static func revert(on connection: Database.Connection) -> Future<Void> {
        return connection.delete(Pivot.self)
    }
}

// MARK: Keys

/// Custom coding keys
internal struct BasicPivotKeys<Left: Model, Right: Model>: CodingKey {
    var stringValue: String
    var intValue: Int? { return Int(stringValue) }

    static var idKey: BasicPivotKeys<Left, Right> {
        return .init("id")
    }

    static var leftIDKey: BasicPivotKeys<Left, Right> {
        return .init(Left.idKey)
    }

    static var rightIDKey: BasicPivotKeys<Left, Right> {
        return .init(Right.idKey)
    }

    init(_ string: String) {
        self.stringValue = string
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        self.init(intValue.description)
    }
}

