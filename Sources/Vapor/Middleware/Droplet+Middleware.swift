extension Droplet {
    /// Requests and responses pass through the `Middleware`
    public func middleware() throws -> [Middleware] {
        return try make([Middleware.self])
    }
}
