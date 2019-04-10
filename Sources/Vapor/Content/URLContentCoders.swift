public protocol URLContentDecoder {
    func decode<D>(_ decodable: D.Type, from url: URL) throws -> D
        where D: Decodable
}

public protocol URLContentEncoder {
    func encode<E>(_ encodable: E, to url: inout URL) throws
        where E: Encodable
}
