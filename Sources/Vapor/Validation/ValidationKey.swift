public enum ValidationKey {
    case integer(Int)
    case string(String)
}

extension ValidationKey: CodingKey {
    public var stringValue: String {
        switch self {
        case .integer(let integer):
            return integer.description
        case .string(let string):
            return string
        }
    }
    
    public var intValue: Int? {
        switch self {
        case .integer(let integer):
            return integer
        case .string:
            return nil
        }
    }
    
    public init?(stringValue: String) {
        self = .string(stringValue)
    }
    
    public init?(intValue: Int) {
        self = .integer(intValue)
    }
}

extension ValidationKey: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension ValidationKey: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .integer(value)
    }
}

extension ValidationKey: CustomStringConvertible {
    public var description: String {
        self.stringValue
    }
}
