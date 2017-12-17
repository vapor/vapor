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
    func encode(to res: inout Response, for req: Request) throws -> Future<Void>
}

/// Can be converted from and to a response
public typealias ResponseCodable = ResponseDecodable & ResponseEncodable

// MARK: Response Conformance

extension Response: ResponseEncodable {
    /// See ResponseRepresentable.makeResponse
    public func encode(to res: inout Response, for req: Request) throws -> Future<Void> {
        res = self
        return .done
    }
}

extension HTTPResponse: ResponseEncodable {
    /// See ResponseRepresentable.makeResponse
    public func encode(to res: inout Response, for req: Request) throws -> Future<Void> {
        let new = req.makeResponse()
        new.http = self
        res = new
        return .done
    }
}
