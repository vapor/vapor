/// Represents a header value with optional parameter metadata.
///
/// Parses a header string like `application/json; charset="utf8"`, into:
///
/// - value: `"application/json"`
/// - parameters: ["charset": "utf8"]
///
/// Simplified format:
///
///     headervalue := value *(";" parameter)
///     ; Matching of media type and subtype
///     ; is ALWAYS case-insensitive.
///
///     value := token
///
///     parameter := attribute "=" value
///
///     attribute := token
///     ; Matching of attributes
///     ; is ALWAYS case-insensitive.
///
///     token := 1*<any (US-ASCII) CHAR except SPACE, CTLs,
///         or tspecials>
///
///     value := token
///     ; token MAY be quoted
///
///     tspecials :=  "(" / ")" / "<" / ">" / "@" /
///                   "," / ";" / ":" / "\" / <">
///                   "/" / "[" / "]" / "?" / "="
///     ; Must be in quoted-string,
///     ; to use within parameter values
public struct HTTPHeaderValue: Codable {
    /// The `HeaderValue`'s main value.
    ///
    /// In the `HeaderValue` `"application/json; charset=utf8"`:
    ///
    /// - value: `"application/json"`
    public var value: String
    
    /// The `HeaderValue`'s metadata. Zero or more key/value pairs.
    ///
    /// In the `HeaderValue` `"application/json; charset=utf8"`:
    ///
    /// - parameters: ["charset": "utf8"]
    public var parameters: [String: String]
    
    /// Creates a new `HeaderValue`.
    public init(_ value: String, parameters: [String: String] = [:]) {
        self.value = value
        self.parameters = parameters
    }
    
    /// Initialize a `HTTPHeaderValue` from a Decoder.
    ///
    /// This will decode a `String` from the decoder and parse it to a `HTTPHeaderValue`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let tempValue = HTTPHeaderValue.parse(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid header value string")
        }
        self.parameters = tempValue.parameters
        self.value = tempValue.value
    }
    
    /// Encode a `HTTPHeaderValue` into an Encoder.
    ///
    /// This will encode the `HTTPHeaderValue` as a `String`.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.serialize())
    }
    
    /// Serializes this `HeaderValue` to a `String`.
    public func serialize() -> String {
        var string = "\(self.value)"
        for (key, val) in self.parameters {
            string += "; \(key)=\"\(val)\""
        }
        return string
    }
    
    /// Parse a `HeaderValue` from a `String`.
    ///
    ///     guard let headerValue = HTTPHeaderValue.parse("application/json; charset=utf8") else { ... }
    ///
    public static func parse(_ data: String, hasValue: Bool = true) -> HTTPHeaderValue? {
        /// The main parameter value
        let value: Substring
        /// get the remaining parameters string
        var remaining: Substring

        /// collect all of the parameters
        var parameters: [String: String] = [:]

        if hasValue {
            /// separate the zero or more parameters
            let parts = data.split(separator: ";", maxSplits: 1)
            /// there must be at least one part, the value
            guard let firstValue = parts.first else {
                /// should never hit this
                return nil
            }
            value = firstValue

            switch parts.count {
            case 1:
                /// no parameters, early exit
                remaining = ""
            case 2:
                remaining = parts[1]
            default:
                return nil
            }
        } else {
            value = ""
            remaining = .init(data)
        }
        
        /// loop over all parts after the value
        parse: while remaining.count > 0 {
            let semicolon = remaining.firstIndex(of: ";")
            let equals = remaining.firstIndex(of: "=")
            
            let key: Substring
            let val: Substring
            
            if equals == nil || (equals != nil && semicolon != nil && semicolon! < equals!) {
                /// parsing a single flag, without =
                key = remaining[remaining.startIndex..<(semicolon ?? remaining.endIndex)]
                val = .init()
                if let s = semicolon {
                    remaining = remaining[remaining.index(after: s)...]
                } else {
                    remaining = .init()
                }
            } else {
                /// parsing a normal key=value pair.
                /// parse the parameters by splitting on the `=`
                let parameterParts = remaining.split(separator: "=", maxSplits: 1)
                
                key = parameterParts[0]
                
                switch parameterParts.count {
                case 1:
                    val = .init()
                    remaining = .init()
                case 2:
                    let trailing = parameterParts[1]
                    
                    if trailing.first == "\"" {
                        /// find first unescaped quote
                        var quoteIndex: String.Index?
                        var escapedIndexes: [String.Index] = []
                        findQuote: for i in 1..<trailing.count {
                            let prev = trailing.index(trailing.startIndex, offsetBy: i - 1)
                            let curr = trailing.index(trailing.startIndex, offsetBy: i)
                            if trailing[curr] == "\"" {
                                if trailing[prev] != #"\"# {
                                    quoteIndex = curr
                                    break findQuote
                                } else {
                                    escapedIndexes.append(prev)
                                }
                            }
                        }
                        
                        guard let i = quoteIndex else {
                            /// could never find a closing quote
                            return nil
                        }
                        
                        var valpart = trailing[trailing.index(after: trailing.startIndex)..<i]
                        
                        if escapedIndexes.count > 0 {
                            /// go reverse so that we can correctly remove multiple
                            for escapeLoc in escapedIndexes.reversed() {
                                valpart.remove(at: escapeLoc)
                            }
                        }
                        
                        val = valpart
                        
                        let rest = trailing[trailing.index(after: trailing.startIndex)...]
                        if let nextSemicolon = rest.firstIndex(of: ";") {
                            remaining = rest[rest.index(after: nextSemicolon)...]
                        } else {
                            remaining = .init()
                        }
                    } else {
                        /// find first semicolon
                        var semicolonOffset: String.Index?
                        findSemicolon: for i in 0..<trailing.count {
                            let curr = trailing.index(trailing.startIndex, offsetBy: i)
                            if trailing[curr] == ";" {
                                semicolonOffset = curr
                                break findSemicolon
                            }
                        }
                        
                        if let i = semicolonOffset {
                            /// cut to next semicolon
                            val = trailing[trailing.startIndex..<i]
                            remaining = trailing[trailing.index(after: i)...]
                        } else {
                            /// no more semicolons
                            val = trailing
                            remaining = .init()
                        }
                    }
                default:
                    /// the parameter was not form `foo=bar`
                    return nil
                }
            }
            
            let trimmedKey = String(key).trimmingCharacters(in: .whitespaces)
            let trimmedVal = String(val).trimmingCharacters(in: .whitespaces)
            parameters[.init(trimmedKey)] = .init(trimmedVal)
        }
        
        return .init(.init(value), parameters: parameters)
    }
}
