extension Droplet {
    public func middleware() throws -> [Middleware] {
        return try make([Middleware.self])
    }
}
