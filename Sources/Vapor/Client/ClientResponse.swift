import NIOCore
import HTTPTypes
import Foundation

public struct ClientResponse: Sendable {
    public var status: HTTPStatus
    public var headers: HTTPFields
    public var body: ByteBuffer?
    private let byteBufferAllocator: ByteBufferAllocator
    private let contentConfiguration: ContentConfiguration

    public init(status: HTTPStatus = .ok, headers: HTTPFields = [:], body: ByteBuffer? = nil, byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator(), contentConfiguration: ContentConfiguration = .default()) {
        self.status = status
        self.headers = headers
        self.body = body
        self.byteBufferAllocator = byteBufferAllocator
        self.contentConfiguration = contentConfiguration
    }
}

extension ClientResponse {
    private struct _ContentContainer: ContentContainer {
        var body: ByteBuffer?
        var headers: HTTPFields
        let allocator: ByteBufferAllocator
        let contentConfiguration: ContentConfiguration

        var contentType: HTTPMediaType? {
            return self.headers.contentType
        }

        mutating func encode<E>(_ encodable: E, using encoder: any ContentEncoder) throws where E : Encodable {
            var body = self.allocator.buffer(capacity: 0)
            try encoder.encode(encodable, to: &body, headers: &self.headers)
            self.body = body
        }

        func decode<D>(_ decodable: D.Type, using decoder: any ContentDecoder) throws -> D where D : Decodable {
            guard let body = self.body else {
                throw Abort(.lengthRequired)
            }
            return try decoder.decode(D.self, from: body, headers: self.headers)
        }

        mutating func encode<C>(_ content: C, using encoder: any ContentEncoder) throws where C : Content {
            var body = self.allocator.buffer(capacity: 0)
            var content = content
            try content.beforeEncode()
            try encoder.encode(content, to: &body, headers: &self.headers)
            self.body = body
        }

        func decode<C>(_ content: C.Type, using decoder: any ContentDecoder) throws -> C where C : Content {
            guard let body = self.body else {
                throw Abort(.lengthRequired)
            }
            var decoded = try decoder.decode(C.self, from: body, headers: self.headers)
            try decoded.afterDecode()
            return decoded
        }
    }

    public var content: any ContentContainer {
        get {
            return _ContentContainer(body: self.body, headers: self.headers, allocator: self.byteBufferAllocator, contentConfiguration: self.contentConfiguration)
        }
        set {
            let container = (newValue as! _ContentContainer)
            self.body = container.body
            self.headers = container.headers
        }
    }
}

extension ClientResponse: CustomStringConvertible {
    public var description: String {
        var desc = ["HTTP/1.1 \(status.code) \(status.reasonPhrase)"]
        desc += self.headers.map { "\($0.name): \($0.value)" }
        if var body = self.body {
            let string = body.readString(length: body.readableBytes) ?? ""
            desc += ["", string]
        }
        return desc.joined(separator: "\n")
    }
}

extension ClientResponse: ResponseEncodable {
    public func encodeResponse(for request: Request) async throws -> Response {
        let body: Response.Body
        if let buffer = self.body {
            body = .init(buffer: buffer, byteBufferAllocator: request.byteBufferAllocator)
        } else {
            body = .empty
        }
        let response = Response(
            status: self.status,
            headers: self.headers,
            body: body,
            contentConfiguration: request.application.contentConfiguration
        )
        return response
    }
}

extension ClientResponse: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.status == rhs.status && lhs.headers == rhs.headers && lhs.body == rhs.body
    }
}
