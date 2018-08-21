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
public protocol Content: Codable, ResponseCodable, RequestCodable {
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
    static var defaultContentType: MediaType { get }
}

/// MARK: Default Implementations

extension Content {
    /// Default implementation is `MediaType.json` for all types.
    ///
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .json
    }

    /// Default `RequestEncodable` conformance.
    ///
    /// See `RequestEncodable`.
    public func encode(using container: Container) throws -> Future<Request> {
        let req = Request(using: container)
        try req.content.encode(self)
        return Future.map(on: container) { req }
    }

    /// Default `ResponseEncodable` conformance.
    ///
    /// See `ResponseEncodable`.
    public func encode(for req: Request) throws -> Future<Response> {
        let res = req.response()
        try res.content.encode(self)
        return Future.map(on: req) { res }
    }

    /// Default `RequestDecodable` conformance.
    ///
    /// See `RequestDecodable`.
    public static func decode(from req: Request) throws -> Future<Self> {
        let content = try req.content.decode(Self.self)
        return content
    }

    /// Default `ResponseDecodable` conformance.
    ///
    /// See `ResponseDecodable`.
    public static func decode(from res: Response, for req: Request) throws -> Future<Self> {
        let content = try res.content.decode(Self.self)
        return content
    }
}

// MARK: Default Conformances

extension String: Content {
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .plainText
    }
}

extension Int: Content {
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .plainText
    }
}

extension Int8: Content {
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .plainText
    }
}

extension Int16: Content {
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .plainText
    }
}

extension Int32: Content {
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .plainText
    }
}

extension Int64: Content {
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .plainText
    }
}

extension UInt: Content {
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .plainText
    }
}

extension UInt8: Content {
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .plainText
    }
}

extension UInt16: Content {
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .plainText
    }
}

extension UInt32: Content {
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .plainText
    }
}

extension UInt64: Content {
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .plainText
    }
}

extension Double: Content {
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .plainText
    }
}

extension Float: Content {
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .plainText
    }
}

extension Array: Content, RequestDecodable, RequestEncodable, ResponseDecodable, ResponseEncodable where Element: Content {
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .json
    }
}

extension Dictionary: Content, RequestDecodable, RequestEncodable, ResponseDecodable, ResponseEncodable where Key == String, Value: Content {
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .json
    }
}
