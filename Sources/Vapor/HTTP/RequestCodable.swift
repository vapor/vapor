/// Can be decoded from a `Request`.
public protocol RequestDecodable {
    /// Decodes `Self` from a `Request`.
    static func decode(from req: Request) throws -> Future<Self>
}

/// Can be encoded to a `Request`.
public protocol RequestEncodable {
    /// Encodes `Self` to a `Request`.
    func encode(using container: Container) throws -> Future<Request>
}

/// Can be converted from and to a request
public typealias RequestCodable = RequestDecodable & RequestEncodable

extension Request: RequestEncodable {
    /// See `RequestEncodable`.
    public func encode(using container: Container) throws -> Future<Request> {
        return Future.map(on: container) { self }
    }
}

extension Request: RequestDecodable {
    /// See `RequestDecodable`.
    public static func decode(from request: Request) throws -> Future<Request> {
        return Future.map(on: request) { request }
    }
}
