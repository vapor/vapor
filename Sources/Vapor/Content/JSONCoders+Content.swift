import Foundation
import NIOCore
import NIOHTTP1

extension JSONEncoder: ContentEncoder {
    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders) throws
        where E: Encodable
    {
        headers.contentType = .json
        try body.writeBytes(self.encode(encodable))
    }
}

extension JSONDecoder: ContentDecoder {
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D
        where D: Decodable
    {
        let data = body.getData(at: body.readerIndex, length: body.readableBytes) ?? Data()
        return try self.decode(D.self, from: data)
    }
}
