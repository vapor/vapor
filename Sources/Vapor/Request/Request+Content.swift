import MediaType

// TODO: Tanner, seems export is necessary
@_exported import PathIndexable

public protocol RequestContentSubscript {}

extension String: RequestContentSubscript { }
extension Int: RequestContentSubscript {}

public extension Request {
    /**
        The data received from the request in json body or url query
    */
    public struct Content {
        // MARK: Initialization
        public let query: StructuredData
        public let json: JSON?
        public let formEncoded: StructuredData?
        public let multipart: [String: MultiPart]?

        internal init(
            query: StructuredData,
            json: JSON?,
            formEncoded: StructuredData?,
            multipart: [String: MultiPart]?
        ) {
            self.query = query
            self.json = json
            self.formEncoded = formEncoded
            self.multipart = multipart
        }

        // MARK: Subscripting
        public subscript(index: Int) -> Polymorphic? {
            if let value = query["\(index)"] {
                return value
            } else if let value = json?.array?[index] {
                return value
            } else if let value = formEncoded?["\(index)"] {
                return value
            } else if let value = multipart?["\(index)"] {
                return value
            } else {
                return nil
            }
        }

        public subscript(key: String) -> Polymorphic? {
            if let value = query[key] {
                return value
            } else if let value = json?.object?[key] {
                return value
            } else if let value = formEncoded?[key] {
                return value
            } else if let value = multipart?[key] {
                return value
            } else {
                return nil
            }
        }

        public subscript(indexes: PathIndex...) -> Polymorphic? {
            return self[indexes]
        }

        public subscript(indexes: [PathIndex]) -> Polymorphic? {
            if let value = query[indexes] {
                return value
            } else if let value = json?[indexes] {
                return value
            } else if let value = formEncoded?[indexes] {
                return value
            } else {
                return nil
            }
        }
    }

}

extension String: Polymorphic {
    public var isNull: Bool {
        return self == "null"
    }

    public var bool: Bool? {
        return Bool(self)
    }

    public var int: Int? {
        guard let double = double else { return nil }
        return Int(double)
    }

    public var float: Float? {
        guard let double = double else { return nil }
        return Float(double)
    }

    public var double: Double? {
        return Double(self)
    }

    public var string: String? {
        return self
    }

    public var array: [Polymorphic]? {
        return self
            .components(separatedBy: ",")
            .map { $0 as Polymorphic }
    }

    public var object: [String : Polymorphic]? {
        return nil
    }
}

extension Bool {
    /**
        This function seeks to replicate the expected 
        behavior of `var boolValue: Bool` on `NSString`.  
        Any variant of `yes`, `y`, `true`, `t`, or any 
        numerical value greater than 0 will be considered `true`
    */
    public init(_ string: String) {
        let cleaned = string
            .lowercased()
            .characters
            .first ?? "n"

        switch cleaned {
        case "t", "y", "1":
            self = true
        default:
            if let int = Int(String(cleaned)) where int > 0 {
                self = true
            } else {
                self = false
            }

        }
    }
}
