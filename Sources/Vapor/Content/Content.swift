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
public protocol Content: HTTPContent, RequestDecodable, ResponseEncodable { }

public protocol URLContent: Content { }

extension URLContent {
    public static func decodeRequest(
        _ req: HTTPRequest,
        using ctx: Context
    ) -> EventLoopFuture<Self> {
        #warning("TODO:")
        fatalError("not yet implemented")
    }
}

/// MARK: Default Implementations

extension Content {
    public static func decodeRequest(_ req: HTTPRequest, using ctx: Context) -> EventLoopFuture<Self> {
        do {
            let content = try req.decode(Self.self)
            return ctx.eventLoop.makeSucceededFuture(content)
        } catch {
            return ctx.eventLoop.makeFailedFuture(error)
        }
    }
    
    public func encodeResponse(for req: HTTPRequest, using ctx: Context) -> EventLoopFuture<HTTPResponse> {
        var res = HTTPResponse()
        do {
            try res.encode(self)
        } catch {
            return ctx.eventLoop.makeFailedFuture(error)
        }
        return ctx.eventLoop.makeSucceededFuture(res)
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
extension Array: Content, ResponseEncodable, RequestDecodable where Element: Content { }
extension Dictionary: Content, ResponseEncodable, RequestDecodable where Key == String, Value: Content { }
