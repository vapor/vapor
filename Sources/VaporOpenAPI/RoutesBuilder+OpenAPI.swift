#if OpenAPI
public import HTTPTypes
public import Vapor

extension RoutesBuilder {
    /// A builder that describes the routes registered through it in the OpenAPI document.
    ///
    /// Describe a single route by registering it right away, or a group by registering several:
    ///
    /// ```swift
    /// app.openAPI(summary: "Get a user", response: .type(User.self))
    ///     .get("users", ":id") { req in … }
    ///
    /// let users = app.grouped("users").openAPI(tags: ["Users"], auth: [.bearer()])
    /// users.get(":id") { req in … }
    /// users.post { req in … }
    /// ```
    ///
    /// Details nest: a route keeps its own summary, body and response over a group's, while tags,
    /// auth, content types and parameters add up, the group's first.
    ///
    /// - Parameters:
    ///   - tags: Groups the operation in the document's UI.
    ///   - summary: A one-line description of the operation.
    ///   - description: A longer description of the operation.
    ///   - operationID: A unique name for the operation, which client generators use. Set it on
    ///     a single route: on a group it would repeat on every route in it.
    ///   - query: The query parameters.
    ///   - headers: The request headers.
    ///   - path: The path parameters, to give them types. Without it they come from the route's
    ///     path, as strings.
    ///   - cookies: The cookies the operation reads.
    ///   - body: The request body.
    ///   - contentTypes: The request body's content types. If empty, the body type's
    ///     `Content.defaultContentType`, or JSON when it has none.
    ///   - response: The successful response's body. The handler's return type if `nil`.
    ///   - responseContentTypes: The response body's content types. If empty, the body type's
    ///     `Content.defaultContentType`, such as `text/plain` for a `String`, or JSON when it has none.
    ///   - responseHeaders: The headers of the successful response.
    ///   - responseDescription: A description of the successful response.
    ///   - statusCode: The successful response's status. `200 OK` if `nil`.
    ///   - auth: The security schemes the operation accepts.
    ///   - links: Values in the response that other operations take, by the key that ties them.
    ///   - deprecated: Whether the operation is deprecated. `nil` inherits a group's.
    public func openAPI(
        tags: [String] = [],
        summary: String? = nil,
        description: String? = nil,
        operationID: String? = nil,
        query: OpenAPIParameters? = nil,
        headers: OpenAPIParameters? = nil,
        path: OpenAPIParameters? = nil,
        cookies: OpenAPIParameters? = nil,
        body: OpenAPIBody? = nil,
        contentTypes: [HTTPMediaType] = [],
        response: OpenAPIBody? = nil,
        responseContentTypes: [HTTPMediaType] = [],
        responseHeaders: OpenAPIParameters? = nil,
        responseDescription: String? = nil,
        statusCode: HTTPResponse.Status? = nil,
        auth: [OpenAPIAuth] = [],
        links: [OpenAPILink: any OpenAPILinkKey.Type] = [:],
        deprecated: Bool? = nil
    ) -> any RoutesBuilder {
        let details = OpenAPIRoute(
            tags: tags,
            summary: summary,
            description: description,
            operationID: operationID,
            deprecated: deprecated,
            query: query,
            headers: headers,
            path: path,
            cookies: cookies,
            body: body,
            contentTypes: contentTypes,
            response: response,
            responseContentTypes: responseContentTypes,
            responseHeaders: responseHeaders,
            responseDescription: responseDescription,
            statusCode: statusCode,
            auth: auth,
            links: links
        )
        return OpenAPIRoutesGroup(root: self) { $0.merge(details) }
    }

    /// A builder whose routes are left out of the OpenAPI document, such as a health check.
    public func hiddenFromOpenAPI() -> any RoutesBuilder {
        OpenAPIRoutesGroup(root: self) { $0.isHidden = true }
    }
}
#endif
