@_exported import Service

//extension String: Error {}
//
//import Service
//
//extension JSON: Equatable {
//    public static func ==(lhs: JSON, rhs: JSON) -> Bool {
//        switch (lhs, rhs) {
//        case (.object(let a), .object(let b)):
//            return a == b
//        case (.array(let a), .array(let b)):
//            return a == b
//        case (.int(let a), .int(let b)):
//            return a == b
//        case (.string(let a), .string(let b)):
//            return a == b
//        case (.bool(let a), .bool(let b)):
//            return a == b
//        case (.double(let a), .double(let b)):
//            return a == b
//        default:
//            return false
//        }
//    }
//}
//
//extension Config: ExpressibleByStringLiteral {
//    public init(stringLiteral value: String) {
//        self = .string(value)
//    }
//}
//
//extension Config: ExpressibleByIntegerLiteral {
//    public init(integerLiteral value: Int) {
//        self = .int(value)
//    }
//}
//
//extension Config: ExpressibleByArrayLiteral {
//    public init(arrayLiteral elements: Config...) {
//        self = .array(elements)
//    }
//}
//
//extension Config: ExpressibleByDictionaryLiteral {
//    public init(dictionaryLiteral elements: (String, Config)...) {
//        var dict: [String: Config] = [:]
//        for (key, val) in elements {
//            dict[key] = val
//        }
//        self = .dictionary(dict)
//    }
//}

