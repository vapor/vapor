extension Array where Element == any CodingKey {
    public var dotPath: String { self.map(\.stringValue).joined(separator: ".") }
}

/// A basic `CodingKey` implementation.
public enum BasicCodingKey: CodingKey, Hashable {
    /// String representation.
    case key(String)

    /// Integer representation.
    case index(Int)
    
    // See `CodingKey.stringValue`.
    public var stringValue: String {
        switch self {
        case .index(let index): "\(index)"
        case .key(let key):     key
        }
    }
    
    // See `CodingKey.intValue`.
    public var intValue: Int? {
        switch self {
        case .index(let index): index
        case .key(let key):     Int(key)
        }
    }
    
    // See `CodingKey.init(stringValue:)`.
    public init?(stringValue: String) {
        self = .key(stringValue)
    }
    
    // See `CodingKey.init(intValue:)`.
    public init?(intValue: Int) {
        self = .index(intValue)
    }

    /// Create a ``BasicCodingKey`` from the content of any `CodingKey`.
    public init(_ codingKey: some CodingKey) {
        if let intValue = codingKey.intValue {
            self = .index(intValue)
        } else {
            self = .key(codingKey.stringValue)
        }
    }
    
    /// Create a ``BasicCodingKey`` from the coding key of any `CodingKeyRepresentable` value.
    public init(_ codingKeyRepresentable: some CodingKeyRepresentable) {
        self.init(codingKeyRepresentable.codingKey)
    }
}

extension BasicCodingKey: CustomStringConvertible {
    // See `CustomStringConvertible.description`.
    public var description: String {
        switch self {
        case .index(let index): String(describing: index)
        case .key(let key):     String(describing: key)
        }
    }
}

extension BasicCodingKey: CustomDebugStringConvertible {
    // See `CustomDebugStringConvertible.debugDescription`.
    public var debugDescription: String {
        switch self {
        case .index(let index): String(reflecting: index)
        case .key(let key):     String(reflecting: key)
        }
    }
}

extension BasicCodingKey: ExpressibleByStringLiteral {
    // See `ExpressibleByStringLiteral.init(stringLiteral:)`.
    public init(stringLiteral: String) {
        self = .key(stringLiteral)
    }
}

extension BasicCodingKey: ExpressibleByIntegerLiteral {
    // See `ExpressibleByIntegerLiteral.init(integerLiteral:)`.
    public init(integerLiteral: Int) {
        self = .index(integerLiteral)
    }
}
