import NIOCore
import HTTPTypes

public struct View: ResponseEncodable, Sendable {
    public var data: ByteBuffer

    public init(data: ByteBuffer) {
        self.data = data
    }

    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response(headers: .init(dictionaryLiteral: (.contentType, HTTPMediaType.html.serialize())), body: .init(buffer: self.data))
        return response
    }
}
