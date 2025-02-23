import NIOCore
import NIOHTTP1
import NIOConcurrencyHelpers
import Vapor

public struct TestingHTTPResponse: Sendable {
    public var status: HTTPStatus
    public var headers: HTTPHeaders
    public var body: ByteBuffer

    package init(status: HTTPStatus, headers: HTTPHeaders, body: ByteBuffer) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

extension TestingHTTPResponse {
    private struct _ContentContainer: ContentContainer {
        var body: ByteBuffer
        var headers: HTTPHeaders

        var contentType: HTTPMediaType? {
            return self.headers.contentType
        }

        mutating func encode<E>(_ encodable: E, using encoder: ContentEncoder) throws where E : Encodable {
            fatalError("Encoding to test response is not supported")
        }

        func decode<D>(_ decodable: D.Type, using decoder: ContentDecoder) throws -> D where D : Decodable {
            try decoder.decode(D.self, from: self.body, headers: self.headers)
        }

        func decode<C>(_ content: C.Type, using decoder: ContentDecoder) throws -> C where C : Content {
            var decoded = try decoder.decode(C.self, from: self.body, headers: self.headers)
            try decoded.afterDecode()
            return decoded
        }
    }

    public var content: ContentContainer {
        _ContentContainer(body: self.body, headers: self.headers)
    }
}
