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

    /// Called before this `Content` is encoded, generally for a `Response` object.
    ///
    /// You should use this method to perform any "sanitizing" which you need on the data.
    /// For example, you may wish to replace empty strings with a `nil`, `trim()` your
    /// strings or replace empty arrays with `nil`. You can also use this method to abort
    /// the encoding if something isn't valid. An empty array may indicate an error, for example.
    mutating func beforeEncode() throws


    /// Called after this `Content` is decoded, generally from a `Request` object.
    ///
    /// You should use this method to perform any "sanitizing" which you need on the data.
    /// For example, you may wish to replace empty strings with a `nil`, `trim()` your
    /// strings or replace empty arrays with `nil`. You can also use this method to abort
    /// the decoding if something isn't valid. An empty string may indicate an error, for example.
    mutating func afterDecode() throws
}

/// MARK: Default Implementations

extension Content {
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

    @_disfavoredOverload
    public mutating func beforeEncode() throws { }
    @_disfavoredOverload
    public mutating func afterDecode() throws { }
}

// MARK: Default Conformances

extension String: Content {
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension FixedWidthInteger where Self: Content {
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
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}
extension Double: Content { }
extension Float: Content { }

extension Array: Content, ResponseEncodable, RequestDecodable where Element: Content {
    public static var defaultContentType: HTTPMediaType {
        return .json
    }

//    public mutating func beforeEncode() throws {
//        for index in 0..<self.count {
//            try self[index].beforeEncode()
//        }
//    }
//
//    public mutating func afterDecode() throws {
//        for index in 0..<self.count {
//            try self[index].afterDecode()
//        }
//    }
}
extension Dictionary: Content, ResponseEncodable, RequestDecodable where Key == String, Value: Content {
    public static var defaultContentType: HTTPMediaType {
        return .json
    }
}
