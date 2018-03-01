import Async
import Foundation
import Service

/// Representable as content in an HTTP message.
public protocol Content: Codable, ResponseCodable, RequestCodable {
    /// The default media type to use when _encoding_ this
    /// content. This can be overridden at the encode call.
    static var defaultMediaType: MediaType { get }
}

extension Content {
    /// See Content.defaultMediaType
    public static var defaultMediaType: MediaType {
        return .json
    }

    /// See RequestEncodable.encode
    public func encode(using container: Container) throws -> Future<Request> {
        let req = Request(using: container)
        try req.content.encode(self)
        return Future.map(on: container) { req }
    }

    /// See ResponseEncodable.encode
    public func encode(for req: Request) throws -> Future<Response> {
        let res = req.makeResponse()
        try res.content.encode(self)
        return Future.map(on: req) { res }
    }

    /// See RequestDecodable.decode
    public static func decode(from req: Request) throws -> Future<Self> {
        let content = try req.content.decode(Self.self)
        return content
    }

    /// See ResponseDecodable.decode
    public static func decode(from res: Response, for req: Request) throws -> Future<Self> {
        let content = try res.content.decode(Self.self)
        return content
    }
}

// MARK: Default Conformance

extension String: Content {
    /// See Content.defaultMediaType
    public static var defaultMediaType: MediaType {
        return .plainText
    }
}

extension Int: Content {
    /// See `Content.defaultMediaType`
    public static var defaultMediaType: MediaType {
        return .plainText
    }
}

extension Int8: Content {
    /// See `Content.defaultMediaType`
    public static var defaultMediaType: MediaType {
        return .plainText
    }
}

extension Int16: Content {
    /// See `Content.defaultMediaType`
    public static var defaultMediaType: MediaType {
        return .plainText
    }
}

extension Int32: Content {
    /// See `Content.defaultMediaType`
    public static var defaultMediaType: MediaType {
        return .plainText
    }
}

extension Int64: Content {
    /// See `Content.defaultMediaType`
    public static var defaultMediaType: MediaType {
        return .plainText
    }
}

extension UInt: Content {
    /// See `Content.defaultMediaType`
    public static var defaultMediaType: MediaType {
        return .plainText
    }
}

extension UInt8: Content {
    /// See `Content.defaultMediaType`
    public static var defaultMediaType: MediaType {
        return .plainText
    }
}

extension UInt16: Content {
    /// See `Content.defaultMediaType`
    public static var defaultMediaType: MediaType {
        return .plainText
    }
}

extension UInt32: Content {
    /// See `Content.defaultMediaType`
    public static var defaultMediaType: MediaType {
        return .plainText
    }
}

extension UInt64: Content {
    /// See `Content.defaultMediaType`
    public static var defaultMediaType: MediaType {
        return .plainText
    }
}

extension Double: Content {
    /// See `Content.defaultMediaType`
    public static var defaultMediaType: MediaType {
        return .plainText
    }
}

extension Float: Content {
    /// See `Content.defaultMediaType`
    public static var defaultMediaType: MediaType {
        return .plainText
    }
}

extension Array: Content, RequestDecodable, RequestEncodable, ResponseDecodable, ResponseEncodable where Element: Content {
    /// See `Content.defaultMediaType`
    public static var defaultMediaType: MediaType {
        return Element.defaultMediaType
    }
}

extension Dictionary: Content, RequestDecodable, RequestEncodable, ResponseDecodable, ResponseEncodable where Key == String, Value: Content {
    /// See `Content.defaultMediaType`
    public static var defaultMediaType: MediaType {
        return Value.defaultMediaType
    }
}

extension Request {
    public func makeResponse() -> Response {
        return Response(using: superContainer)
    }
}

extension Response {
    public func makeRequest() -> Request {
        return Request(using: superContainer)
    }
}
