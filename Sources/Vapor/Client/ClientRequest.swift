import NIOCore
import Foundation
import HTTPTypes

public struct ClientRequest: Sendable {
    public var method: HTTPRequest.Method
    public var url: URI
    public var headers: HTTPFields
    public var body: ByteBuffer?
    public var timeout: TimeAmount?
    private let byteBufferAllocator: ByteBufferAllocator
    private let contentConfiguration: ContentConfiguration

    public init(
        method: HTTPRequest.Method = .get,
        url: URI = "/",
        headers: HTTPFields = [:],
        body: ByteBuffer? = nil,
        timeout: TimeAmount?,
        byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator(),
        contentConfiguration: ContentConfiguration = .default()
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.timeout = timeout
        self.byteBufferAllocator = byteBufferAllocator
        self.contentConfiguration = contentConfiguration
    }

    public init(
        method: HTTPRequest.Method = .get,
        url: URI = "/",
        headers: HTTPFields = [:],
        body: ByteBuffer? = nil,
        byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator(),
        contentConfiguration: ContentConfiguration = .default()
    ) {
        self.init(method: method,
                  url: url,
                  headers: headers,
                  body: body,
                  timeout: nil,
                  byteBufferAllocator: byteBufferAllocator,
                  contentConfiguration: contentConfiguration)
    }
}

extension ClientRequest {
    private struct _URLQueryContainer: URLQueryContainer {
        var url: URI
        let contentConfiguration: ContentConfiguration

        func decode<D>(_ decodable: D.Type, using decoder: URLQueryDecoder) throws -> D
            where D: Decodable
        {
            return try decoder.decode(D.self, from: self.url)
        }

        mutating func encode<E>(_ encodable: E, using encoder: URLQueryEncoder) throws
            where E: Encodable
        {
            try encoder.encode(encodable, to: &self.url)
        }
    }

    public var query: URLQueryContainer {
        get {
            return _URLQueryContainer(url: self.url, contentConfiguration: self.contentConfiguration)
        }
        set {
            self.url = (newValue as! _URLQueryContainer).url
        }
    }

    private struct _ContentContainer: ContentContainer {
        var body: ByteBuffer?
        var headers: HTTPFields
        let byteBufferAllocator: ByteBufferAllocator
        let contentConfiguration: ContentConfiguration

        var contentType: HTTPMediaType? {
            return self.headers.contentType
        }

        mutating func encode<E>(_ encodable: E, using encoder: ContentEncoder) throws where E : Encodable {
            var body = self.byteBufferAllocator.buffer(capacity: 0)
            try encoder.encode(encodable, to: &body, headers: &self.headers)
            self.body = body
        }

        func decode<D>(_ decodable: D.Type, using decoder: ContentDecoder) throws -> D where D : Decodable {
            guard let body = self.body else {
                throw Abort(.lengthRequired)
            }
            return try decoder.decode(D.self, from: body, headers: self.headers)
        }

        mutating func encode<C>(_ content: C, using encoder: ContentEncoder) throws where C : Content {
            var content = content
            try content.beforeEncode()
            var body = self.byteBufferAllocator.buffer(capacity: 0)
            try encoder.encode(content, to: &body, headers: &self.headers)
            self.body = body
        }

        func decode<C>(_ content: C.Type, using decoder: ContentDecoder) throws -> C where C : Content {
            guard let body = self.body else {
                throw Abort(.lengthRequired)
            }
            var decoded = try decoder.decode(C.self, from: body, headers: self.headers)
            try decoded.afterDecode()
            return decoded
        }
    }

    public var content: ContentContainer {
        get {
            return _ContentContainer(body: self.body, headers: self.headers, byteBufferAllocator: self.byteBufferAllocator, contentConfiguration: self.contentConfiguration)
        }
        set {
            let container = (newValue as! _ContentContainer)
            self.body = container.body
            self.headers = container.headers
        }
    }
}
