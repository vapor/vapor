/// A basic Pivot using two entities:
/// left and right.
/// The pivot itself conforms to entity
/// and can be used like any other Fluent model
/// in preparations, querying, etc.
public final class Pivot<
    L: Model,
    R: Model
>: PivotProtocol, Model {
    public typealias Left = L
    public typealias Right = R

    // MARK: Overridable

    public init(leftId: Encodable, rightId: Encodable) {
        self.leftId = leftId
        self.rightId = rightId
    }
    
    public static var identifier: String {
        if Left.name < Right.name {
            return "Pivot<\(Left.identifier),\(Right.identifier)>"
        } else {
            return "Pivot<\(Right.identifier),\(Left.identifier)>"
        }
    }

//    public static var name: String {
//        get { return _names[identifier] ?? _defaultName }
//        set { _names[identifier] = newValue }
//    }
//
//    public static var entity: String {
//        get { return _entities[identifier] ?? _defaultEntity }
//        set { _entities[identifier] = newValue }
//    }
//
//    public static var rightIdKey: String {
//        get { return _rightIdKeys[identifier] ?? Right.foreignIdKey }
//        set { _rightIdKeys[identifier] = newValue }
//    }
//
//    public static var leftIdKey: String {
//        get { return _leftIdKeys[identifier] ?? Left.foreignIdKey }
//        set { _leftIdKeys[identifier] = newValue }
//    }

    // MARK: Instance

    public var leftId: Encodable
    public var rightId: Encodable
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

    enum CodingKeys: CodingKey {
        case id
        case leftId
        case rightId

        var stringValue: String {
            switch self {
            case .id:
                return Pivot<Left, Right>.idKey
            case .leftId:
                return Left.foreignIdKey
            case .rightId:
                return Right.foreignIdKey
            }
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        leftId = try container.decode(String.self, forKey: .leftId)
        rightId = try container.decode(String.self, forKey: .rightId)
        id = try container.decode(String.self, forKey: .id)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Optional(leftId), forKey: CodingKeys.leftId)
        try container.encode(Optional(rightId), forKey: CodingKeys.rightId)
        try container.encode(id, forKey: .id)
    }
}

extension Pivot: Preparation {
    public static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.foreignId(for: Left.self, foreignIdKey: Left.idKey)
            builder.foreignId(for: Right.self, foreignIdKey: Right.idKey)
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
