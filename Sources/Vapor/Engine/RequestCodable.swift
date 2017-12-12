/// Can be converted from a request.
public protocol RequestDecodable {
    static func decode(from req: Request) throws -> Future<Self>
}

/// Can be converted to a request
public protocol RequestEncodable {
    func encode(to req: inout Request) throws -> Completable
}

/// Can be converted from and to a request
public typealias RequestCodable = RequestDecodable & RequestEncodable

// MARK: Request Conformance

extension Request: RequestEncodable {
    public func encode(to req: inout Request) throws -> Completable {
        req = self
        return .done
    }
}

extension Request: RequestDecodable {
    /// See RequestInitializable.decode
    public static func decode(from request: Request) throws -> Future<Request> {
        return Future(request)
    }
}
