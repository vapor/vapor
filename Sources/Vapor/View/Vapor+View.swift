extension Request {
    // MARK: View

    /// Creates a `ViewRenderer`.
    ///
    ///     router.get("home") { req -> Future<View> in
    ///         return try req.view().make("home", ["message", "Hello, world!"])
    ///     }
    ///
    public func view() throws -> ViewRenderer {
        return try make()
    }
}

extension View: Content {
    // MARK: Content
    
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .html
    }
}

extension ViewRenderer {
    // MARK: Render

    /// Renders the template at the supplied path with an empty context.
    ///
    ///     try req.view().make("home")
    ///
    /// - parameters:
    ///     - path: Path to file containing the template.
    /// - returns: `Future` containing the rendered `View`.
    public func render(_ path: String) -> Future<View> {
        let empty: [String: String] = [:]
        return render(path, empty)
    }
}
