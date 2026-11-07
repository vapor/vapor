#if OpenAPI
import OpenAPIKit
import Vapor

extension Route {
    /// This route as an OpenAPI operation, with the path it sits under.
    ///
    /// Schemas it refers to are stored in `components`. Throws when the route can't be described,
    /// naming the route.
    func operation(into components: inout SchemaComponents) throws -> (path: OpenAPI.Path, operation: OpenAPI.Operation) {
        let template: OpenAPIPath
        do {
            template = try OpenAPIPath(path)
        } catch {
            throw OpenAPIDocumentError(route: description, reason: error.reason)
        }

        do {
            let details = openAPIRoute
            let parameters = try pathParameters(template, into: &components) + otherParameters(into: &components)
            let body = try requestBody(into: &components)
            let responseMap = try responses(into: &components)
            let operation = OpenAPI.Operation(
                tags: details.tags.isEmpty ? nil : details.tags,
                // Vapor's own description of the route, when it isn't described here.
                summary: details.summary ?? routeDescription,
                description: details.description,
                operationId: details.operationID,
                parameters: parameters.map { .b($0) },
                requestBody: body,
                responses: responseMap,
                deprecated: details.deprecated ?? false,
                security: securityRequirements
            )
            return (template.path, operation)
        } catch {
            throw OpenAPIDocumentError(route: description, reason: "\(error)")
        }
    }
}
#endif
