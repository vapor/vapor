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

    public init(status: HTTPResponse.Status = .ok, headers: HTTPFields = [:], body: Response.Body = .empty, contentConfiguration: ContentConfiguration = .default()) {
        self.status = status
        self.headers = headers
        self.body = body
        self.contentConfiguration = contentConfiguration
    }
}

extension ClientResponse {
    private struct _ContentContainer: ContentContainer {
        var body: Response.Body
        var headers: HTTPFields
        let contentConfiguration: ContentConfiguration

        var contentType: HTTPMediaType? {
            return self.headers.contentType
        }

        mutating func encode<E>(_ encodable: E, using encoder: any ContentEncoder) throws where E : Encodable {
            var data = Data()
            try encoder.encode(encodable, to: &data, headers: &self.headers, userInfo: [:])
            self.body = .init(data: data)
        }

        func decode<D>(_ decodable: D.Type, using decoder: any ContentDecoder) throws -> D where D : Decodable {
            guard let body = self.body.data else {
                throw Abort(.lengthRequired)
            }
            return try decoder.decode(D.self, from: body, headers: self.headers, userInfo: [:])
        }

        mutating func encode<C>(_ content: C, using encoder: any ContentEncoder) throws where C : Content {
            var body = Data()
            var content = content
            try content.beforeEncode()
            try encoder.encode(content, to: &body, headers: &self.headers, userInfo: [:])
            self.body = .init(data: body)
        }

        func decode<C>(_ content: C.Type, using decoder: any ContentDecoder) throws -> C where C : Content {
            guard let body = self.body.data else {
                throw Abort(.lengthRequired)
            }
            var decoded = try decoder.decode(C.self, from: body, headers: self.headers, userInfo: [:])
            try decoded.afterDecode()
            return decoded
        }
    }

    public var content: any ContentContainer {
        get {
            _ContentContainer(body: self.body, headers: self.headers, contentConfiguration: self.contentConfiguration)
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
        Response(
            status: self.status,
            headers: self.headers,
            body: .empty,
            contentConfiguration: request.application.contentConfiguration
        )
    }
}
