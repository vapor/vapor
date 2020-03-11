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
@available(*, deprecated)
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
    public static func parse(_ data: String) -> HTTPHeaderValue? {
        var parser = HTTPHeaderValueParser(string: data)
        guard let value = parser.nextValue() else {
            return nil
        }
        var parameters: [String: String] = [:]
        while let (key, value) = parser.nextParameter() {
            parameters[key] = value
        }
        return .init(value, parameters: parameters)
    }
}
