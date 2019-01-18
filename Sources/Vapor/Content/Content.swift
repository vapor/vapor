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
public protocol Content: Codable, ResponseEncodable {
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

    /// See `HTTPRequestCodable`.
    public static func decode(from req: HTTPRequest) throws -> Self {
        return try req.content.decode(Self.self)
    }
    
    /// See `HTTPRequestCodable`.
    public func encode() throws -> HTTPRequest {
        let req = HTTPRequest()
        try req.content.encode(self)
        return req
    }
    
    // See `HTTPResponseDecodable`.
    public static func decode(from res: HTTPResponse, for req: HTTPRequest) throws -> Self {
        return try res.content.decode(Self.self)
    }
    
    // See `HTTPResponseDecodable`.
    public func encode(for req: RequestContext) -> EventLoopFuture<HTTPResponse> {
        let res = HTTPResponse()
        do {
            try res.content.encode(self)
            return req.eventLoop.makeSucceededFuture(result: res)
        } catch {
            return req.eventLoop.makeFailedFuture(error: error)
        }
    }
}

// MARK: Default Conformances

extension String: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Int: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Int8: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Int16: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Int32: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Int64: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension UInt: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension UInt8: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension UInt16: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension UInt32: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension UInt64: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Double: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Float: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Array: Content, ResponseEncodable where Element: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .json
    }
}

extension Dictionary: Content, ResponseEncodable where Key == String, Value: Content {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .json
    }
}
