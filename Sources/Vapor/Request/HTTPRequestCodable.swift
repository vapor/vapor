import NIO
import HTTP

/// Can be initialized from a `Request`.
public protocol HTTPRequestDecodable {
    /// Decodes an instance of `Self` from a `HTTPRequest`.
    ///
    /// - parameters:
    ///     - req: The `HTTPRequest` to initialize from.
    /// - returns: A `HTTPRequest` containing an instance of `Self`.
    static func decode(from req: HTTPRequest) throws -> Self
}

/// Can convert `self` to a `Request`.
public protocol HTTPRequestEncodable {
    /// Encodes an instance of `Self` to a `HTTPRequest`.
    ///
    /// - returns: A `HTTPRequest` containing the `Request`.
    func encode() throws -> HTTPRequest
}

/// Can be converted to and from a `HTTPRequest`.
public typealias HTTPRequestCodable = HTTPRequestDecodable & HTTPRequestEncodable

// MARK: Default Conformances

extension HTTPRequest: HTTPRequestCodable {
    /// See `HTTPRequestCodable`.
    public static func decode(from req: HTTPRequest) -> HTTPRequest {
        return req
    }
    
    /// See `HTTPRequestCodable`.
    public func encode() -> HTTPRequest {
        return self
    }
}
