#warning("Make internal")
public import NIOCore
import NIOFoundationEssentialsCompat
import HTTPTypes
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct View: ResponseEncodable, Sendable {
    public var data: ByteBuffer

    public init(data: ByteBuffer) {
        self.data = data
    }

    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response(headers: .init(dictionaryLiteral: (.contentType, HTTPMediaType.html.serialize())), body: .init(data: self.data.getData(at: 0, length: self.data.readableBytes) ?? Data()))
        return response
    }
}
