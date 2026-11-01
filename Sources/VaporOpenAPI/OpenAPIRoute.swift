#if OpenAPI
import HTTPTypes
import Vapor

/// What a route says about itself in the OpenAPI document, collected from the `openAPI` builders
/// around it before it's registered.
///
/// Every property is optional or empty by default, so a builder sets only what it knows. The
/// route's method and path come from the route itself, when the document is built.
struct OpenAPIRoute: Sendable {
    var tags: [String] = []
    var summary: String?
    var description: String?
    var operationID: String?
    var deprecated = false
    /// Leaves the route out of the document.
    var isHidden = false

    var query: OpenAPIParameters?
    var headers: OpenAPIParameters?
    /// Types the path parameters, which otherwise come from the route's path as strings.
    var path: OpenAPIParameters?
    var cookies: OpenAPIParameters?

    var body: OpenAPIBody?
    var contentTypes: [HTTPMediaType] = []

    /// The successful response, or the route's handler return type when it's `nil`.
    var response: OpenAPIBody?
    var responseContentTypes: [HTTPMediaType] = []
    var responseHeaders: OpenAPIParameters?
    var responseDescription: String?
    /// `200 OK` when it's `nil`.
    var statusCode: HTTPResponse.Status?

    var auth: [OpenAPIAuth] = []
    var links: [OpenAPILink: any OpenAPILinkKey.Type] = [:]
}

extension Route {
    /// The route's OpenAPI description, empty until a builder sets something.
    var openAPIRoute: OpenAPIRoute {
        get { openAPI as? OpenAPIRoute ?? OpenAPIRoute() }
        set { openAPI = newValue }
    }
}
#endif
