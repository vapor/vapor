/// Convertible to / from content in an HTTP message.
///
/// Conformance to this protocol consists of:
/// - `ResponseEncodable`
/// - `ResponseDecodable`
/// - `RequestEncodable`
/// - `RequestDecodable`
///
/// If adding conformance in an extension, you must ensure the type already exists to `Codable`.
///
///     struct Hello: Content {
///         let message = "Hello!"
///     }
///
///     router.get("greeting") { req in
///         return Hello() // {"message":"Hello!"}
///     }
///
public protocol Content: HTTPContent, ResponseEncodable { }

/// MARK: Default Implementations

extension Content {
    public func encode(for req: RequestContext) -> EventLoopFuture<HTTPResponse> {
        return self.encode(status: .ok, for: req)
    }
    
    /// Encodes an instance of `Self` to a `HTTPResponse`.
    ///
    /// - parameters:
    ///     - req: The `HTTPRequest` associated with this `HTTPResponse`.
    /// - returns: An `HTTPResponse`.
    public func encode(
        status: HTTPStatus,
        headers: HTTPHeaders = .init(),
        for req: RequestContext
    ) -> EventLoopFuture<HTTPResponse> {
        var res = HTTPResponse(status: status, headers: headers)
        do {
            try res.encode(self)
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
        return req.eventLoop.makeSucceededFuture(res)
    }
}

// MARK: Default Conformances

extension String: Content { }
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
extension Double: Content { }
extension Float: Content { }
extension Array: Content, ResponseEncodable where Element: Content { }
extension Dictionary: Content, ResponseEncodable where Key == String, Value: Content { }
