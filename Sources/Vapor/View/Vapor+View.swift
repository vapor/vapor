import Async

extension View: Content {
    /// See Content.defaultContentType
    public static var defaultContentType: MediaType {
        return .html
    }
}

extension Request {
    /// Creates a `TemplateRenderer` service.
    public func view() throws -> TemplateRenderer {
        return try make(TemplateRenderer.self)
    }
}
