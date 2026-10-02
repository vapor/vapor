/// Convertible to content in an HTTP message.
///
/// Conformance to this protocol consists of:
///
/// - `Encodable`
/// - `ResponseEncodable`
///
/// Use it for types that are only ever encoded, such as response models, so they don't have to be `Decodable`.
/// Types that are also decoded from requests conform to ``Content``, which refines this protocol.
///
///     struct Greeting: ContentEncodable {
///         let message = "Hello!"
///     }
///
///     router.get("greeting") { req in
///         return Greeting() // {"message":"Hello!"}
///     }
///
public protocol ContentEncodable: Encodable, ResponseEncodable, Sendable {
    /// The default `MediaType` to use when _encoding_ content. This can always be overridden at the encode call.
    ///
    /// Default implementation is `MediaType.json` for all types.
    ///
    ///     struct Hello: Content {
    ///         static let defaultContentType = .urlEncodedForm
    ///         let message = "Hello!"
    ///     }
    ///
    ///     router.get("greeting") { req in
    ///         return Hello() // message=Hello!
    ///     }
    ///
    ///     router.get("greeting2") { req in
    ///         let res = req.response()
    ///         try res.content.encode(Hello(), as: .json)
    ///         return res // {"message":"Hello!"}
    ///     }
    ///
    static var defaultContentType: HTTPMediaType { get }

    /// Called before this value is encoded, generally for a `Response` object.
    ///
    /// You should use this method to perform any "sanitizing" which you need on the data.
    /// For example, you may wish to replace empty strings with a `nil`, `trim()` your
    /// strings or replace empty arrays with `nil`. You can also use this method to abort
    /// the encoding if something isn't valid. An empty array may indicate an error, for example.
    mutating func beforeEncode() throws
}

/// Convertible to / from content in an HTTP message.
///
/// Conformance to this protocol consists of:
///
/// - `Codable`
/// - `RequestDecodable`
/// - ``ContentEncodable``, which brings `ResponseEncodable`
///
/// If adding conformance in an extension, you must ensure the type already conforms to `Codable`.
///
///     struct Hello: Content {
///         let message = "Hello!"
///     }
///
///     router.get("greeting") { req in
///         return Hello() // {"message":"Hello!"}
///     }
///
public protocol Content: ContentEncodable, Codable, RequestDecodable {
    /// Called after this `Content` is decoded, generally from a `Request` object.
    ///
    /// You should use this method to perform any "sanitizing" which you need on the data.
    /// For example, you may wish to replace empty strings with a `nil`, `trim()` your
    /// strings or replace empty arrays with `nil`. You can also use this method to abort
    /// the decoding if something isn't valid. An empty string may indicate an error, for example.
    mutating func afterDecode() throws
}

/// MARK: Default Implementations

extension ContentEncodable {
    public static var defaultContentType: HTTPMediaType {
        .json
    }

    public func encodeResponse(for request: Request) async throws -> Response {
        var response = Response(contentConfiguration: request.contentConfiguration)
        try response.content.encode(self)
        return response
    }

    public mutating func beforeEncode() throws {}
}

extension Content {
    public static func decodeRequest(_ request: Request) async throws -> Self {
        try await request.content.decode(Self.self)
    }

    public mutating func afterDecode() throws {}
}

// MARK: Default Conformances

extension String: Content {
    public static var defaultContentType: HTTPMediaType {
        .plainText
    }
}

extension FixedWidthInteger where Self: Content {
    public static var defaultContentType: HTTPMediaType {
        .plainText
    }
}

extension Int: Content {}
extension Int8: Content {}
extension Int16: Content {}
extension Int32: Content {}
extension Int64: Content {}
extension UInt: Content {}
extension UInt8: Content {}
extension UInt16: Content {}
extension UInt32: Content {}
extension UInt64: Content {}

extension Bool: Content {}

extension BinaryFloatingPoint where Self: Content {
    public static var defaultContentType: HTTPMediaType {
        .plainText
    }
}
extension Double: Content {}
extension Float: Content {}

extension Array: ContentEncodable, ResponseEncodable where Element: ContentEncodable {
    public static var defaultContentType: HTTPMediaType {
        .json
    }
}

extension Array: Content, RequestDecodable where Element: Content {}

extension Dictionary: ContentEncodable, ResponseEncodable where Key == String, Value: ContentEncodable {
    public static var defaultContentType: HTTPMediaType {
        .json
    }
}

extension Dictionary: Content, RequestDecodable where Key == String, Value: Content {}
