public protocol URLQueryDecoder {
    func decode<D>(_ decodable: D.Type, from url: URL) throws -> D
        where D: Decodable
}

public protocol URLQueryEncoder {
    func encode<E>(_ encodable: E, to url: inout URL) throws
        where E: Encodable
}
