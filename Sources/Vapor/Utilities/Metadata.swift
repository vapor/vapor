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
    struct DictionaryCodingKeys: CodingKey {
        var stringValue: String
        
        var intValue: Int?
        
        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = "\(intValue)"
        }
        
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .string(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .stringConvertible(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value.description)
        case .dictionary(let value):
            var container = encoder.container(keyedBy: DictionaryCodingKeys.self)
            try value.forEach { (key, value) in
                let codingKey = DictionaryCodingKeys.init(stringValue: key)!
                try container.encode(value, forKey: codingKey)
            }
        case .array(let value):
            var container = encoder.unkeyedContainer()
            try value.forEach { element in
                try container.encode(element)
            }
        }
    }
}
