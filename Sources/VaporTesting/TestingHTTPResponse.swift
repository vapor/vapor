import NIOCore
import Vapor
import HTTPTypes

public struct TestingHTTPResponse: Sendable {
    public var status: HTTPStatus
    public var headers: HTTPFields
    public var body: ByteBuffer
    private let contentConfiguration: ContentConfiguration

    package init(status: HTTPStatus, headers: HTTPFields, body: ByteBuffer, contentConfiguration: ContentConfiguration) {
        self.status = status
        self.headers = headers
        self.body = body
        self.contentConfiguration = contentConfiguration
    }
}

extension TestingHTTPResponse {
    private struct _ContentContainer: ContentContainer {
        var body: ByteBuffer
        var headers: HTTPFields
        let contentConfiguration: ContentConfiguration

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
        _ContentContainer(body: self.body, headers: self.headers, contentConfiguration: self.contentConfiguration)
    }
}
