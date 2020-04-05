import Crypto

/// Convertible to / from content in an HTTP message.
///
/// Conformance to this protocol consists of:
///
/// - `Codable`
/// - `RequestDecodable`
/// - `ResponseEncodable`
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
public protocol Content: Codable, RequestDecodable, ResponseEncodable {
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
}

/// MARK: Default Implementations

extension Content {
    /// Default implementation is `MediaType.json` for all types.
    ///
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .json
    }
    
    public static func decodeRequest(_ request: Request) -> EventLoopFuture<Self> {
        do {
            let content = try request.content.decode(Self.self)
            return request.eventLoop.makeSucceededFuture(content)
        } catch {
            return request.eventLoop.makeFailedFuture(error)
        }
    }
    
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let response = Response()
        do {
            try response.content.encode(self)
        } catch {
            return request.eventLoop.makeFailedFuture(error)
        }
        return request.eventLoop.makeSucceededFuture(response)
    }

    public func eTag() throws -> String? {
        // Hardcode the JSON media type here. Regardless of what type the client
        // asks for, the ETag always needs to be the same, which means we always
        // have to encode with a single known type that doesn't change.  Must also
        // sort the keys or output form is random which would lead to different
        // eTag for the same object
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let data = try encoder.encode(self)

        let eTag = Array(SHA256.hash(data: data)).hexEncodedString()

        return #""\#(eTag)""#
    }
}

// MARK: Default Conformances

extension String: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension FixedWidthInteger where Self: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Int: Content { }
extension Int8: Content { }
extension Int16: Content { }
extension Int32: Content { }
extension Int64: Content { }
extension UInt: Content { }
extension UInt8: Content { }
extension UInt16: Content { }
extension UInt32: Content { }
extension UInt64: Content { }

extension BinaryFloatingPoint where Self: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}
extension Double: Content { }
extension Float: Content { }

extension Array: Content, ResponseEncodable, RequestDecodable where Element: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .json
    }
}
extension Dictionary: Content, ResponseEncodable, RequestDecodable where Key == String, Value: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .json
    }
}
