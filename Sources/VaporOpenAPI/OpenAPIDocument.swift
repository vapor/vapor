#if OpenAPI
import OpenAPIKit

/// An OpenAPI document describing an app's routes, ready to be encoded as JSON.
///
/// Build one with `app.routes.openAPI(info:)`. We wrap OpenAPIKit's document rather than expose it,
/// so OpenAPIKit's major versions don't leak into Vapor's API.
public struct OpenAPIDocument: Encodable, Sendable {
    let document: OpenAPI.Document

    public func encode(to encoder: any Encoder) throws {
        try document.encode(to: encoder)
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
