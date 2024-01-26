public protocol URLQueryDecoder {
    func decode<D>(_ decodable: D.Type, from url: URI) throws -> D
        where D: Decodable

    func decode<D>(_ decodable: D.Type, from url: URI, userInfo: [CodingUserInfoKey: Sendable]) throws -> D
        where D: Decodable
}

public protocol URLQueryEncoder {
    func encode<E>(_ encodable: E, to url: inout URI) throws
        where E: Encodable

    func encode<E>(_ encodable: E, to url: inout URI, userInfo: [CodingUserInfoKey: Sendable]) throws
        where E: Encodable
}

extension URLQueryEncoder {
    public func encode<E>(_ encodable: E, to url: inout URI, userInfo: [CodingUserInfoKey: Sendable]) throws
        where E: Encodable
    {
        try self.encode(encodable, to: &url)
    }
}

extension URLQueryDecoder {
    public func decode<D>(_ decodable: D.Type, from url: URI, userInfo: [CodingUserInfoKey: Sendable]) throws -> D
        where D: Decodable
    {
        try self.decode(decodable, from: url)
    }
}
