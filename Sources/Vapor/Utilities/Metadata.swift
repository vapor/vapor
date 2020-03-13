public typealias Metadata = [String: MetadataValue]

public enum MetadataValue {
    case string(String)
    case stringConvertible(CustomStringConvertible)
    case dictionary(Metadata)
    case array([Metadata.Value])
}

extension MetadataValue: Equatable {
    public static func == (lhs: Metadata.Value, rhs: Metadata.Value) -> Bool {
        switch (lhs, rhs) {
        case (.string(let lhs), .string(let rhs)):
            return lhs == rhs
        case (.stringConvertible(let lhs), .stringConvertible(let rhs)):
            return lhs.description == rhs.description
        case (.array(let lhs), .array(let rhs)):
            return lhs == rhs
        case (.dictionary(let lhs), .dictionary(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

extension MetadataValue: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension MetadataValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dictionary(let dict):
            return dict.mapValues { $0.description }.description
        case .array(let list):
            return list.map { $0.description }.description
        case .string(let str):
            return str
        case .stringConvertible(let repr):
            return repr.description
        }
    }
}

extension MetadataValue: ExpressibleByStringInterpolation {}

extension MetadataValue: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = Metadata.Value

    public init(dictionaryLiteral elements: (String, Metadata.Value)...) {
        self = .dictionary(.init(uniqueKeysWithValues: elements))
    }
}

extension MetadataValue: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Metadata.Value

    public init(arrayLiteral elements: Metadata.Value...) {
        self = .array(elements)
    }
}

extension MetadataValue: Encodable {
    enum CodingKeys: String, CodingKey {
        case string
        case stringConvertible
        case dictionary
        case array
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string(let value):
            try container.encode(value, forKey: .string)
        case .stringConvertible(let value):
            try container.encode(value.description, forKey: .stringConvertible)
        case .dictionary(let value):
            try container.encode(value, forKey: .dictionary)
        case .array(let value):
            try container.encode(value, forKey: .array)
        }
    }
}
