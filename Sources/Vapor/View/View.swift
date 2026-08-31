import HTTPTypes
#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

public struct View: ResponseEncodable, Sendable {
    public var data: Data

    public init(data: Data) {
        self.data = data
    }

    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response(headers: .init(dictionaryLiteral: (.contentType, HTTPMediaType.html.serialize())), body: .init(data: self.data))
        return response
    }
}
