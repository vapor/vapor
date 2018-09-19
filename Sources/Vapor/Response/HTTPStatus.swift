/// Less verbose typealias for `HTTPResponseStatus`.
public typealias HTTPStatus = HTTPResponseStatus

extension HTTPStatus: Codable {
    
    /// See [`Decodable.init(from:)`](https://developer.apple.com/documentation/swift/decodable/2894081-init).
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let code = try container.decode(Int.self)
        self = .init(statusCode: code)
    }
    
    /// See [`Encodable.encode(to:)`](https://developer.apple.com/documentation/swift/encodable/2893603-encode).
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.code)
    }
}

extension HTTPStatus: Content {
    
    /// See `ResponseDecodable`.
    public static func decode(from res: Response, for req: Request) throws -> Future<HTTPStatus> {
        return req.future(res.http.status)
    }
    
    /// See `ResponseEncodable`.
    public func encode(for req: Request) throws -> Future<Response> {
        let res = Response(http: .init(status: self), using: req)
        return req.future(res)
    }
}
