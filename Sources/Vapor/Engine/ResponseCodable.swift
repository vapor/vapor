/// Can be converted from a response.
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/response/#responseinitializable)
public protocol ResponseDecodable {
    static func decode(from res: Response, for req: Request) throws -> Future<Self>
}

/// Can be converted to a response
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/response/#responserepresentable)
public protocol ResponseEncodable {
    /// Makes a response using the context provided by the HTTPRequest
    func encode(to res: inout Response, for req: Request) throws -> Completable
}

/// Can be converted from and to a response
public typealias ResponseCodable = ResponseDecodable & ResponseEncodable

// MARK: Response Conformance

extension Response: ResponseEncodable {
    /// See ResponseRepresentable.makeResponse
    public func encode(to res: inout Response, for req: Request) throws -> Completable {
        res = self
        return .done
    }
}

extension HTTPResponse: ResponseEncodable {
    public typealias Expectation = HTTPResponse

    /// See ResponseRepresentable.makeResponse
    public func encode(to res: inout Response, for req: Request) throws -> Completable {
        let new = req.makeResponse()
        new.http = self
        res = new
        return .done
    }
}
