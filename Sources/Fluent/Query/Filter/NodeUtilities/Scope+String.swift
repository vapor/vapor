///// Filter.Scope <-> String
//extension Filter.Scope {
//    public var string: String {
//        switch(self) {
//        case .`in`: return "in"
//        case .notIn: return "notIn"
//        }
//    }
//
//    public init(_ string: String) throws {
//        switch(string) {
//        case "in": self = .`in`
//        case "notIn": self = .notIn
//        default: throw FilterSerializationError.undefinedScope(string)
//        }
//    }
//}

