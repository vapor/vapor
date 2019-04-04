public protocol ResponseEncoder {
    func encode<E>(_ encodable: E, to response: Response) throws
        where E: Encodable
}

public protocol RequestDecoder {
    func decode<D>(_ decodable: D.Type, from request: Request) throws -> D
        where D: Decodable
}
