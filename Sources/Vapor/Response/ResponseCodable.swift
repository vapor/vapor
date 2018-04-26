/// Can be converted from a response.
public protocol ResponseDecodable {
    static func decode(from res: Response, for req: Request) throws -> Future<Self>
}

/// Can be converted to a response
public protocol ResponseEncodable {
    /// Makes a response using the context provided by the HTTPRequest
    func encode(for req: Request) throws -> Future<Response>
}

/// Can be converted from and to a response
public typealias ResponseCodable = ResponseDecodable & ResponseEncodable

// MARK: Response Conformance

extension Response: ResponseEncodable {
    /// See ResponseRepresentable.makeResponse
    public func encode(for req: Request) throws -> Future<Response> {
        return Future.map(on: req) { self }
    }
}

extension HTTPResponse: ResponseEncodable {
    /// See ResponseRepresentable.makeResponse
    public func encode(for req: Request) throws -> Future<Response> {
        let new = req.makeResponse()
        new.http = self
        return req.eventLoop.newSucceededFuture(result: new)
    }
}

extension StaticString: ResponseEncodable {
    /// See `ResponseEncodable`.
    public func encode(for req: Request) throws -> Future<Response> {
        let res = Response(http: .init(headers: staticStringHeaders, body: self), using: req.sharedContainer)
        return req.eventLoop.newSucceededFuture(result: res)
    }
}

private let staticStringHeaders: HTTPHeaders = ["Content-Type": "text/plain"]
