#if OpenAPI
import HTTPTypes
public import RoutingKit
public import Vapor

extension RoutesBuilder {
    /// Serves the OpenAPI document of `routes` at `path/openapi.json`, and a page showing it at `path`.
    ///
    /// ```swift
    /// app.grouped(adminAuth).openAPIDocumentation("docs", of: app.routes, info: OpenAPIInfo(title: "Pets", version: "1.0.0"))
    /// ```
    ///
    /// Both routes are hidden from the document. Register them through a group to protect them,
    /// such as one with an authentication middleware.
    ///
    /// - Parameters:
    ///   - path: Where the page is served.
    ///   - routes: The routes the document describes, usually `app.routes`.
    ///   - info: What the document says about the API.
    ///   - title: The page's title, the API's title if `nil`.
    public func openAPIDocumentation(_ path: PathComponent..., of routes: Routes, info: OpenAPIInfo, title: String? = nil) {
        openAPIDocumentation(path, of: routes, info: info, title: title)
    }

    /// Serves the OpenAPI document of `routes` at `path/openapi.json`, and a page showing it at `path`.
    public func openAPIDocumentation(_ path: [PathComponent], of routes: Routes, info: OpenAPIInfo, title: String? = nil) {
        let documentation = hiddenFromOpenAPI()
        // Weak, since the application keeps this route, so a strong reference would be a cycle.
        documentation.get(path + ["openapi.json"]) { [weak application = routes.owner] _ in
            guard let application else { throw Abort(.serviceUnavailable) }
            return try application.routes.openAPI(info: info)
        }
        documentation.get(path) { request in
            StoplightPage(title: title ?? info.title, documentURL: StoplightPage.documentURL(from: request.url.path))
        }
    }
}

extension Routes {
    /// Serves the OpenAPI document of these routes at `path/openapi.json`, and a page showing it at `path`.
    public func openAPIDocumentation(_ path: PathComponent..., info: OpenAPIInfo, title: String? = nil) {
        openAPIDocumentation(path, of: self, info: info, title: title)
    }

    /// Serves the OpenAPI document of these routes at `path/openapi.json`, and a page showing it at `path`.
    public func openAPIDocumentation(_ path: [PathComponent], info: OpenAPIInfo, title: String? = nil) {
        openAPIDocumentation(path, of: self, info: info, title: title)
    }
}

extension Application {
    /// Serves the OpenAPI document of the app's routes at `path/openapi.json`, and a page showing it at `path`.
    ///
    /// ```swift
    /// app.openAPIDocumentation("docs", info: OpenAPIInfo(title: "Pets", version: "1.0.0"))
    /// ```
    public func openAPIDocumentation(_ path: PathComponent..., info: OpenAPIInfo, title: String? = nil) {
        routes.openAPIDocumentation(path, info: info, title: title)
    }

    /// Serves the OpenAPI document of the app's routes at `path/openapi.json`, and a page showing it at `path`.
    public func openAPIDocumentation(_ path: [PathComponent], info: OpenAPIInfo, title: String? = nil) {
        routes.openAPIDocumentation(path, info: info, title: title)
    }
}
#endif
