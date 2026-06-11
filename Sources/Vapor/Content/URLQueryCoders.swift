public protocol URLQueryDecoder: Sendable {
    func decode<D>(_ decodable: D.Type, from url: URI) throws -> D
        where D: Decodable

    func decode<D>(_ decodable: D.Type, from url: URI, userInfo: [CodingUserInfoKey: any Sendable]) throws -> D
        where D: Decodable
}

public protocol URLQueryEncoder: Sendable {
    func encode(_ encodable: some Encodable, to url: inout URI) throws

    func encode(_ encodable: some Encodable, to url: inout URI, userInfo: [CodingUserInfoKey: any Sendable]) throws
}

extension URLQueryEncoder {
    public func encode(_ encodable: some Encodable, to url: inout URI, userInfo: [CodingUserInfoKey: any Sendable]) throws {
        try self.encode(encodable, to: &url)
    }
}

extension URLQueryDecoder {
    public func decode<D>(_ decodable: D.Type, from url: URI, userInfo: [CodingUserInfoKey: any Sendable]) throws -> D
        where D: Decodable
    {
        try self.decode(decodable, from: url)
    }
}
