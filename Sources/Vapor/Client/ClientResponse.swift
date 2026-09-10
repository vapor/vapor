public import HTTPTypes
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct ClientResponse: Sendable {
    public var status: HTTPResponse.Status
    public var headers: HTTPFields
    public var body: Response.Body {
        didSet {
            self.headers.updateContentLength(body.count)
        }
    }
    private let contentConfiguration: ContentConfiguration
    /// The most bytes ``content`` will buffer when decoding a streaming body.
    ///
    /// A response arriving from somewhere else is not bounded by anything this process controls, so
    /// collecting one has to have a ceiling. Streaming it with ``Response/Body/withStreamingBytes(_:)``
    /// is not limited by this - only holding the whole thing in memory is.
    public let maxBodySize: Int

    public init(
        status: HTTPResponse.Status = .ok,
        headers: HTTPFields = [:],
        body: Response.Body = .empty,
        maxBodySize: Int = 10 * 1024 * 1024, // Default to 10 MB, matching `ClientRequest`
        contentConfiguration: ContentConfiguration = .default()
    ) {
        self.status = status
        self.headers = headers
        self.body = body
        self.maxBodySize = maxBodySize
        self.contentConfiguration = contentConfiguration
    }
}

extension ClientResponse {
    private struct _ContentContainer: ContentContainer {
        var body: Response.Body
        var headers: HTTPFields
        let maxBodySize: Int
        let contentConfiguration: ContentConfiguration

        var contentType: HTTPMediaType? {
            return self.headers.contentType
        }

        mutating func encode<E>(_ encodable: E, using encoder: any ContentEncoder) throws where E : Encodable {
            var data = Data()
            try encoder.encode(encodable, to: &data, headers: &self.headers, userInfo: [:])
            self.body = .init(data: data)
        }

        func decode<D>(_ decodable: D.Type, using decoder: any ContentDecoder) async throws -> D where D : Decodable {
            var body = self.body
            guard let data = try await body.collect(max: self.maxBodySize) else {
                throw Abort(.lengthRequired)
            }
            return try decoder.decode(D.self, from: data, headers: self.headers, userInfo: [:])
        }

        mutating func encode<C>(_ content: C, using encoder: any ContentEncoder) throws where C : Content {
            var body = Data()
            var content = content
            try content.beforeEncode()
            try encoder.encode(content, to: &body, headers: &self.headers, userInfo: [:])
            self.body = .init(data: body)
        }
    }

    public var content: any ContentContainer {
        get {
            _ContentContainer(body: self.body, headers: self.headers, maxBodySize: self.maxBodySize, contentConfiguration: self.contentConfiguration)
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
        if let body = self.body.string {
            desc += ["", body]
        }
        return desc.joined(separator: "\n")
    }
}

extension ClientResponse: ResponseEncodable {
    public func encodeResponse(for request: Request) async throws -> Response {
        // Returning a client response from a handler is proxying, so the origin's connection-specific
        // fields have to go: its `Connection: close` would close *our* client's connection, and its
        // framing headers describe a hop this response is not travelling over. `Response.init` then
        // sets the framing to match the body actually being sent.
        var headers = self.headers
        headers.removeHopByHopFields()
        return Response(
            status: self.status,
            headers: headers,
            body: self.body,
            contentConfiguration: request.contentConfiguration
        )
    }
}
