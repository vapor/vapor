public import Vapor
public import HTTPTypes
#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

public struct TestingHTTPResponse: Sendable {
    public var status: HTTPResponse.Status
    public var headers: HTTPFields
    public var body: Data
    private let contentConfiguration: ContentConfiguration

    package init(status: HTTPResponse.Status, headers: HTTPFields, body: Data, contentConfiguration: ContentConfiguration) {
        self.status = status
        self.headers = headers
        self.body = body
        self.contentConfiguration = contentConfiguration
    }
}

extension TestingHTTPResponse {
    private struct _ContentContainer: ContentContainer {
        var body: Data
        var headers: HTTPFields
        let contentConfiguration: ContentConfiguration

        var contentType: HTTPMediaType? {
            return self.headers.contentType
        }

        mutating func encode<E>(_ encodable: E, using encoder: any ContentEncoder) throws where E : Encodable {
            fatalError("Encoding to test response is not supported")
        }

        func decode<D>(_ decodable: D.Type, using decoder: any ContentDecoder) throws -> D where D : Decodable {
            try decoder.decode(D.self, from: self.body, headers: self.headers, userInfo: [:])
        }
    }

    public var content: any ContentContainer {
        _ContentContainer(body: self.body, headers: self.headers, contentConfiguration: self.contentConfiguration)
    }
}
