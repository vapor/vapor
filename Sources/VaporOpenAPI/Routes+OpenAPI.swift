#if OpenAPI
import OpenAPIKit
public import Vapor

extension Routes {
    /// An OpenAPI document describing these routes, except those hidden from it.
    ///
    /// ```swift
    /// let document = try app.routes.openAPI(info: OpenAPIInfo(title: "Pets", version: "1.0.0"))
    /// ```
    ///
    /// Throws when a route can't be described, naming the route and why.
    public func openAPI(info: OpenAPIInfo) throws -> OpenAPIDocument {
        let routes = all.filter { !$0.openAPIRoute.isHidden }
        var components = SchemaComponents()
        var paths: OpenAPI.PathItem.Map = [:]

        for route in routes {
            let (path, operation) = try route.operation(into: &components)
            var item = paths[path]?.pathItemValue ?? OpenAPI.PathItem()
            item.set(operation: operation, for: OpenAPI.HttpMethod(route.method))
            paths[path] = .b(item)
        }

        let securitySchemes = try routes.securitySchemes()
        let openAPIComponents = OpenAPI.Components(schemas: components.schemas, securitySchemes: securitySchemes)
        let document = OpenAPI.Document(
            info: info.info,
            servers: [],
            paths: paths,
            components: openAPIComponents,
            tags: routes.tags
        )
        return OpenAPIDocument(document: document)
    }
}
#endif
