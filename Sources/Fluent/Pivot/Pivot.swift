/// A basic Pivot using two entities:
/// left and right.
/// The pivot itself conforms to entity
/// and can be used like any other Fluent model
/// in preparations, querying, etc.
public final class Pivot<
    L: Entity,
    R: Entity
>: PivotProtocol, Entity {
    public typealias Left = L
    public typealias Right = R

    // MARK: Overridable
    
    public static var identifier: String {
        if Left.name < Right.name {
            return "Pivot<\(Left.identifier),\(Right.identifier)>"
        } else {
            return "Pivot<\(Right.identifier),\(Left.identifier)>"
        }
    }

    public static var name: String {
        get { return _names[identifier] ?? _defaultName }
        set { _names[identifier] = newValue }
    }
    
    public static var entity: String {
        get { return _entities[identifier] ?? _defaultEntity }
        set { _entities[identifier] = newValue }
    }
    
    public static var rightIdKey: String {
        get { return _rightIdKeys[identifier] ?? Right.foreignIdKey }
        set { _rightIdKeys[identifier] = newValue }
    }
    
    public static var leftIdKey: String {
        get { return _leftIdKeys[identifier] ?? Left.foreignIdKey }
        set { _leftIdKeys[identifier] = newValue }
    }
    
    // MARK: Instance

    public var leftId: Identifier
    public var rightId: Identifier
    public let storage = Storage()

    public init(_ left: Left, _ right: Right) throws {
        guard left.exists else {
            throw PivotError.existRequired(left)
        }

        guard let leftId = left.id else {
            throw PivotError.idRequired(left)
        }

        guard right.exists else {
            throw PivotError.existRequired(right)
        }

        guard let rightId = right.id else {
            throw PivotError.idRequired(right)
        }

        self.leftId = leftId
        self.rightId = rightId
    }

    public init(row: Row) throws {
        leftId = try row.get(type(of: self).leftIdKey)
        rightId = try row.get(type(of: self).rightIdKey)

        id = try row.get(idKey)
    }

    public func makeRow() throws -> Row {
        var row = Row()
        try row.set(idKey, id)
        try row.set(type(of: self).leftIdKey, leftId)
        try row.set(type(of: self).rightIdKey, rightId)
        return row
    }
}

extension Pivot: Preparation {
    public static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.foreignId(for: Left.self, foreignIdKey: leftIdKey)
            builder.foreignId(for: Right.self, foreignIdKey: rightIdKey)
        }
    }

    public static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

public var pivotNameConnector: String = "_"

// MARK: Entity / Name

private var _names: [String: String] = [:]
private var _entities: [String: String] = [:]
private var _leftIdKeys: [String: String] = [:]
private var _rightIdKeys: [String: String] = [:]

extension Pivot {
    internal static var _defaultName: String {
        if Left.name < Right.name {
            return "\(Left.name)\(pivotNameConnector)\(Right.name)"
        } else {
            return "\(Right.name)\(pivotNameConnector)\(Left.name)"
        }
    }
    
    internal static var _defaultEntity: String {
        return name
    }
}
