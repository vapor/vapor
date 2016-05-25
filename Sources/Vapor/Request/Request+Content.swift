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
        public let json: Json?
        public let formEncoded: StructuredData?
        public let multipart: [String: MultiPart]?

        internal init(
            query: StructuredData,
            json: Json?,
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
            return query[indexes] ?? json?[indexes] ?? formEncoded?[indexes]
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
            .split(byString: ",")
            .map { $0 as Polymorphic }
    }

    public var object: [String : Polymorphic]? {
        return nil
    }
}


extension String {

    /**
        Query data is information appended to the URL path
        as `key=value` pairs separated by `&` after
        an initial `?`

        - returns: String dictionary of parsed Query data
     */
    internal func queryData() -> [String: String] {
        // First `?` indicates query, subsequent `?` should be included as part of the arguments
        return split(separator: "?", maxSplits: 1)
            .dropFirst()
            .reduce("", combine: +)
            .keyValuePairs()
    }

    /**
        Parses `key=value` pair data separated by `&`.

        - returns: String dictionary of parsed data
     */
    internal func keyValuePairs() -> [String: String] {
        var data: [String: String] = [:]

        for pair in self.split(byString: "&") {
            let tokens = pair.split(separator: "=", maxSplits: 1)

            if
                let name = tokens.first,
                let value = tokens.last,
                let parsedName = try? String(percentEncoded: name) {
                data[parsedName] = try? String(percentEncoded: value)
            }
        }

        return data
    }

}

extension Bool {
    /**
        This function seeks to replicate the expected behavior of `var boolValue: Bool` on `NSString`.  Any variant of `yes`, `y`, `true`, `t`, or any numerical value greater than 0 will be considered `true`
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
