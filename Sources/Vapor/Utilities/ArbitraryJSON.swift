public enum ArbitraryJSON: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case dictionary([String: ArbitraryJSON])
    case array([ArbitraryJSON])

    enum Key: CodingKey {
        case string(String)
        case int(Int)

        init?(intValue: Int) {
            self = .int(intValue)
        }

        init?(stringValue: String) {
            self = .string(stringValue)
        }

        var intValue: Int? {
            switch self {
            case .int(let int):
                return int
            case.string:
                return nil
            }
        }

        var stringValue: String {
            switch self {
            case .int(let int):
                return int.description
            case.string(let string):
                return string
            }
        }
    }

    public init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: Key.self) {
            self = try .dictionary(.init(
                uniqueKeysWithValues: keyed.allKeys.map { key in
                    try (key.stringValue, keyed.decode(ArbitraryJSON.self, forKey: key))
                }
            ))
        } else if var unkeyed = try? decoder.unkeyedContainer() {
            self = try .array((0..<unkeyed.count!).map { i in
                try unkeyed.decode(ArbitraryJSON.self)
            })
        } else {
            let singleValue = try decoder.singleValueContainer()
            if let double = try? singleValue.decode(Double.self) {
                self = .double(double)
            } else if let int = try? singleValue.decode(Int.self) {
                self = .int(int)
            } else if let bool = try? singleValue.decode(Bool.self) {
                self = .bool(bool)
            } else {
                self = try .string(singleValue.decode(String.self))
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .string(let string):
            var singleValue = encoder.singleValueContainer()
            try singleValue.encode(string)
        case .int(let int):
            var singleValue = encoder.singleValueContainer()
            try singleValue.encode(int)
        case .double(let double):
            var singleValue = encoder.singleValueContainer()
            try singleValue.encode(double)
        case .bool(let bool):
            var singleValue = encoder.singleValueContainer()
            try singleValue.encode(bool)
        case .dictionary(let dictionary):
            var keyed = encoder.container(keyedBy: Key.self)
            try dictionary.forEach { (key, value) in
                try keyed.encode(value, forKey: .string(key))
            }
        case .array(let array):
            var unkeyed = encoder.unkeyedContainer()
            try array.forEach { value in
                try unkeyed.encode(value)
            }
        }
    }
}
