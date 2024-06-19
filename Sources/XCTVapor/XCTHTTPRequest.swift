import NIOCore
import NIOHTTP1
import NIOConcurrencyHelpers
import Vapor

public struct XCTHTTPRequest: Sendable {
    public var method: HTTPMethod
    public var url: URI
    public var headers: HTTPHeaders
    public var body: ByteBuffer

    public init(method: HTTPMethod, url: URI, headers: HTTPHeaders, body: ByteBuffer) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }

    private struct _ContentContainer: ContentContainer {
        var body: ByteBuffer
        var headers: HTTPHeaders

        var contentType: HTTPMediaType? {
            return self.headers.contentType
        }

        mutating func encode<E>(_ encodable: E, using encoder: ContentEncoder) throws where E : Encodable {
            try encoder.encode(encodable, to: &self.body, headers: &self.headers)
        }

        func decode<D>(_ decodable: D.Type, using decoder: ContentDecoder) throws -> D where D : Decodable {
            fatalError("Decoding from test request is not supported.")
        }

        mutating func encode<C>(_ content: C, using encoder: ContentEncoder) throws where C : Content {
            var content = content
            try content.beforeEncode()
            try encoder.encode(content, to: &self.body, headers: &self.headers)
        }
    }

    public var content: ContentContainer {
        get {
            _ContentContainer(body: self.body, headers: self.headers)
        }
        set {
            let content = (newValue as! _ContentContainer)
            self.body = content.body
            self.headers = content.headers
        }
    }

    private struct _URLQueryContainer: URLQueryContainer {
        var url: URI

        func decode<D>(_ decodable: D.Type, using decoder: URLQueryDecoder) throws -> D
            where D: Decodable
        {
            fatalError("Decoding from test request is not supported.")
        }

        mutating func encode<E>(_ encodable: E, using encoder: URLQueryEncoder) throws
            where E: Encodable
        {
            try encoder.encode(encodable, to: &self.url)
        }
    }

    public var query: URLQueryContainer {
        get {
            _URLQueryContainer(url: url)
        }
        set {
            let query = (newValue as! _URLQueryContainer)
            self.url = query.url
        }
    }
}
