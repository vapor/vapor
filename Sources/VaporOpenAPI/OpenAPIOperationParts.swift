#if OpenAPI
import HTTPTypes
import OpenAPIKit
import Vapor

/// The pieces of an operation, each built from a route's OpenAPI details.
///
/// `operation(for:into:)` puts them together; these only translate to OpenAPIKit's types.
extension Route {
    /// The path parameters: one per name in `path`, typed by the route's `path:` details where
    /// they have one, otherwise a required string.
    func pathParameters(_ path: OpenAPIPath, into components: inout SchemaComponents) throws -> [OpenAPI.Parameter] {
        var typed: [String: OpenAPI.Parameter] = [:]
        for parameter in try openAPIRoute.path?.value.parameters(in: .path, into: &components) ?? [] {
            typed[parameter.name] = parameter
        }
        return path.parameters.map { name in
            typed[name] ?? .parameter(name: name, location: .path, required: true, schema: .string, example: nil)
        }
    }

    /// The query, header and cookie parameters, in that order.
    func otherParameters(into components: inout SchemaComponents) throws -> [OpenAPI.Parameter] {
        let details = openAPIRoute
        return try (details.query?.value.parameters(in: .query, into: &components) ?? [])
            + (details.headers?.value.parameters(in: .header, into: &components) ?? [])
            + (details.cookies?.value.parameters(in: .cookie, into: &components) ?? [])
    }

    /// The request body, or `nil` when the route doesn't describe one.
    func requestBody(into components: inout SchemaComponents) throws -> OpenAPI.Request? {
        let details = openAPIRoute
        guard let body = details.body else { return nil }
        let content = try OpenAPI.Content.map(body.value, contentTypes: details.contentTypes, into: &components)
        return OpenAPI.Request(content: content, required: true)
    }

    /// The successful response, keyed by its status.
    ///
    /// Its body is the route's `response:`, or else the handler's return type when that can be
    /// described, or else none.
    func responses(into components: inout SchemaComponents) throws -> OpenAPI.Response.Map {
        let details = openAPIRoute
        let status = details.statusCode ?? .ok
        let body = details.response?.value ?? handlerResponse
        // Without content types of its own, the body is sent as Vapor sends it, such as a `String`
        // as `text/plain`.
        let contentTypes =
            details.responseContentTypes.isEmpty
            ? body?.defaultContentType.map { [$0] } ?? []
            : details.responseContentTypes
        let content =
            try body.map { try OpenAPI.Content.map($0, contentTypes: contentTypes, into: &components) }
            ?? [:]
        let headers = try details.responseHeaders.map { try OpenAPI.Header.map($0, into: &components) }
        let response = OpenAPI.Response(
            description: details.responseDescription ?? status.reasonPhrase,
            headers: headers,
            content: content
        )
        return [.status(code: status.code): .b(response)]
    }

    /// The handler's return type as a body, when it's a type we can describe.
    private var handlerResponse: OpenAPIValue? {
        guard responseType != Response.self,
            let type = responseType as? any (Decodable & SendableMetatype).Type
        else { return nil }
        return .type(type)
    }

    /// One requirement per scheme, since an operation accepts any of the schemes it lists.
    var securityRequirements: [OpenAPI.SecurityRequirement]? {
        let auth = openAPIRoute.auth
        guard !auth.isEmpty else { return nil }
        return auth.map { [.component(named: $0.id): $0.scopes] }
    }
}

extension OpenAPIValue {
    /// The content type Vapor sends this value as, from its `Content` conformance.
    ///
    /// `nil` when that isn't known, such as for a type that isn't `Content`, or a composition
    /// whose parts are sent differently.
    var defaultContentType: HTTPMediaType? {
        switch self {
        case .type(let type):
            (type as? any Content.Type)?.defaultContentType
        case .example(let value):
            (Swift.type(of: value) as? any Content.Type)?.defaultContentType
        case .allOf(let values), .anyOf(let values), .oneOf(let values):
            Self.shared(values.map(\.defaultContentType))
        case .not:
            nil
        }
    }

    /// The content type all of `types` share, if they're all known and the same.
    private static func shared(_ types: [HTTPMediaType?]) -> HTTPMediaType? {
        guard let first = types.first, let first,
            types.allSatisfy({ $0?.description == first.description })
        else { return nil }
        return first
    }
}

extension OpenAPI.Content {
    /// The same schema and example for each of `contentTypes`, or for JSON when there are none.
    static func map(
        _ value: OpenAPIValue,
        contentTypes: [HTTPMediaType],
        into components: inout SchemaComponents
    ) throws -> OpenAPI.Content.Map {
        let (schema, example) = try value.schema(into: &components)
        var map: OpenAPI.Content.Map = [:]
        for type in OpenAPI.ContentType.types(for: contentTypes) {
            map[type] = .b(OpenAPI.Content(schema: schema, example: example))
        }
        return map
    }
}

extension OpenAPI.Header {
    /// One header per property of `parameters`, as response headers are described.
    static func map(_ parameters: OpenAPIParameters, into components: inout SchemaComponents) throws -> Map {
        var map: Map = [:]
        for parameter in try parameters.value.parameters(in: .header, into: &components) {
            map[parameter.name] = .b(
                OpenAPI.Header(schemaOrContent: parameter.schemaOrContent, required: parameter.required)
            )
        }
        return map
    }
}
#endif
