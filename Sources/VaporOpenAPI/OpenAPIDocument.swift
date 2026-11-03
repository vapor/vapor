#if OpenAPI
import HTTPTypes
import OpenAPIKit
public import Vapor

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

/// An OpenAPI document describing an app's routes, ready to be encoded as JSON.
///
/// Build one with `app.routes.openAPI(info:)`. We wrap OpenAPIKit's document rather than expose it,
/// so OpenAPIKit's major versions don't leak into Vapor's API.
public struct OpenAPIDocument: Encodable, Sendable {
    let document: OpenAPI.Document

    public func encode(to encoder: any Encoder) throws {
        try document.encode(to: encoder)
    }

    /// The document as JSON, with sorted keys so it's the same on every run.
    ///
    /// Without sorting, `JSONEncoder` writes an object's keys in a different order each time.
    public func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

extension OpenAPIDocument: ResponseEncodable {
    /// The document as a JSON response.
    public func encodeResponse(for request: Request) async throws -> Response {
        var headers = HTTPFields()
        headers.contentType = .json
        return Response(headers: headers, body: .init(data: try json()))
    }
}

/// What the document says about the API itself.
public struct OpenAPIInfo: Sendable {
    /// The name of the API.
    public var title: String
    /// The version of the API, such as `1.0.0`, not of OpenAPI.
    public var version: String
    /// A one-line description of the API.
    public var summary: String?
    /// A longer description of the API.
    public var description: String?

    public init(title: String, version: String, summary: String? = nil, description: String? = nil) {
        self.title = title
        self.version = version
        self.summary = summary
        self.description = description
    }

    var info: OpenAPI.Document.Info {
        OpenAPI.Document.Info(title: title, summary: summary, description: description, version: version)
    }
}

/// A route the document can't describe, and why.
struct OpenAPIDocumentError: Error, CustomStringConvertible {
    /// The route, such as `GET /users/:id`.
    var route: String
    var reason: String

    var description: String { "\(route): \(reason)" }
}
#endif
