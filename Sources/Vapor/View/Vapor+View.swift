import Async

extension View: Content {
    /// See Content.defaultMediaType
    public static var defaultMediaType: MediaType {
        return .html
    }
}

extension Request {
    /// Creates a `TemplateRenderer` service.
    public func view() throws -> TemplateRenderer {
        return try make(TemplateRenderer.self)
    }
}
