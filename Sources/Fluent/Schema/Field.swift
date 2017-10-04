
/// Various types of fields
/// that can be used in a Schema.
public struct Field {
    public let name: String
    public let type: DataType
    public let optional: Bool
    public let unique: Bool
    public let `default`: Encodable?
    public let primaryKey: Bool

    public enum DataType {
        case id(type: IdentifierType)
        case int
        case string(length: Int?)
        case double
        case bool
        case bytes
        case date
        case custom(type: String)
    }

    public init(
        name: String,
        type: DataType,
        optional: Bool = false,
        unique: Bool = false,
        default: Encodable? = nil,
        primaryKey: Bool = false
    ) {
        self.name = name
        self.type = type
        self.optional = optional
        self.unique = unique
        self.default = `default`
        self.primaryKey = primaryKey
    }
    
    public init(
        name: String,
        type: DataType,
        optional: Bool = false,
        unique: Bool = false,
        default: NodeRepresentable? = nil,
        primaryKey: Bool = false
    ) {
        let node: Node?
        
        if let d = `default` {
            node = try? d.makeNode(in: rowContext)
        } else {
            node = nil
        }
        
        self.init(
            name: name,
            type: type,
            optional: optional,
            unique: unique,
            default: node,
            primaryKey: primaryKey
        )
    }
}

extension Field: Equatable {
    public static func ==(lhs: Field, rhs: Field) -> Bool {
        return lhs.name == rhs.name
            && lhs.type == rhs.type
            && lhs.optional == rhs.optional
            && lhs.unique == rhs.unique
            && lhs.default == rhs.default
            && lhs.primaryKey == rhs.primaryKey
    }
}

extension Field.DataType: Equatable {
    public static func ==(lhs: Field.DataType, rhs: Field.DataType) -> Bool {
        switch (lhs, rhs) {
        case (.id(let a), .id(let b)):
            return a == b
        case (.int, .int),
             (.string, .string),
             (.double, .double),
             (.bool, .bool),
             (.bytes, .bytes),
             (.date, .date):
            return true
        case (.custom(let a), .custom(let b)):
            return a == b
        default:
            return false
        }
    }
}

extension IdentifierType: Equatable {
    public static func ==(lhs: IdentifierType, rhs: IdentifierType) -> Bool {
        switch (lhs, rhs) {
        case (.int, .int),
             (.uuid, .uuid):
            return true
        case (.custom(let a), .custom(let b)):
            return a == b
        default:
            return false
        }
    }
}
