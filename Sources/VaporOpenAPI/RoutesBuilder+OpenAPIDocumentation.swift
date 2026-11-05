#if OpenAPI
import HTTPTypes
public import RoutingKit
public import Vapor

extension RoutesBuilder {
    /// Serves the OpenAPI document of `application`'s routes at `path/openapi.json`, and a page
    /// showing it at `path`.
    ///
    /// ```swift
    /// app.grouped(adminAuth).openAPIDocumentation("docs", of: app, info: OpenAPIInfo(title: "Pets", version: "1.0.0"))
    /// ```
    ///
    /// Both routes are hidden from the document. Register them through a group to protect them,
    /// such as one with an authentication middleware.
    ///
    /// Register the documentation before the application boots. The document is built once, in this
    /// call's own lifecycle handler, from the routes registered by then: routes added afterwards,
    /// including by a lifecycle handler registered after this call, aren't in it. Until then,
    /// `openapi.json` responds with 503 Service Unavailable. A route that can't be described doesn't
    /// stop the application from starting: the error is logged, and `openapi.json` responds with
    /// 500 Internal Server Error, naming the route unless the environment is a release one.
    ///
    /// - Parameters:
    ///   - path: Where the page is served.
    ///   - application: The application whose routes the document describes.
    ///   - info: What the document says about the API.
    ///   - title: The page's title, the API's title if `nil`.
    public func openAPIDocumentation(_ path: PathComponent..., of application: Application, info: OpenAPIInfo, title: String? = nil) {
        openAPIDocumentation(path, of: application, info: info, title: title)
    }

    /// Serves the OpenAPI document of `application`'s routes at `path/openapi.json`, and a page
    /// showing it at `path`.
    ///
    /// The document is built when the application boots, as for the variadic form.
    public func openAPIDocumentation(_ path: [PathComponent], of application: Application, info: OpenAPIInfo, title: String? = nil) {
        // The routes hold only the builder, not the application, so they don't keep it alive.
        let openAPIDocumentationBuilder = OpenAPIDocumentationBuilder(info: info)

        let documentation = hiddenFromOpenAPI()
        documentation.get(path + ["openapi.json"]) { _ in
            try openAPIDocumentationBuilder.response()
        }
        documentation.get(path) { request in
            StoplightPage(title: title ?? info.title, documentURL: StoplightPage.documentURL(from: request.url.path))
        }

        // After the routes, so registering too late fails on the routes, which says what went wrong.
        application.addLifecycleHandler(openAPIDocumentationBuilder)
    }
}

extension Application {
    /// Serves the OpenAPI document of the app's routes at `path/openapi.json`, and a page showing it at `path`.
    ///
    /// ```swift
    /// app.openAPIDocumentation("docs", info: OpenAPIInfo(title: "Pets", version: "1.0.0"))
    /// ```
    ///
    /// Register it before the application boots, which is when the document is built, as for the
    /// `RoutesBuilder` form.
    public func openAPIDocumentation(_ path: PathComponent..., info: OpenAPIInfo, title: String? = nil) {
        routes.openAPIDocumentation(path, of: self, info: info, title: title)
    }

    /// Serves the OpenAPI document of the app's routes at `path/openapi.json`, and a page showing it at `path`.
    ///
    /// Register it before the application boots, which is when the document is built.
    public func openAPIDocumentation(_ path: [PathComponent], info: OpenAPIInfo, title: String? = nil) {
        routes.openAPIDocumentation(path, of: self, info: info, title: title)
    }
}
#endif
