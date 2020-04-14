extension RoutesBuilder {
    // MARK: Path
    
    /// Creates a new `Router` that will automatically prepend the supplied path components.
    ///
    ///     let users = router.grouped("user")
    ///     // Adding "user/auth/" route to router.
    ///     users.get("auth") { ... }
    ///     // adding "user/profile/" route to router
    ///     users.get("profile") { ... }
    ///
    /// - parameters:
    ///     - path: Group path components separated by commas.
    /// - returns: Newly created `Router` wrapped in the path.
    public func grouped(_ path: PathComponent...) -> RoutesBuilder {
        return HTTPRoutesGroup(root: self, path: path, defaultMaxBodySize: self.defaultMaxBodySize)
    }
    
    /// Creates a new `Router` that will automatically prepend the supplied path components.
    ///
    ///     router.group("user") { users in
    ///         // Adding "user/auth/" route to router.
    ///         users.get("auth") { ... }
    ///         // adding "user/profile/" route to router
    ///         users.get("profile") { ... }
    ///     }
    ///
    /// - parameters:
    ///     - path: Group path components separated by commas.
    ///     - configure: Closure to configure the newly created `Router`.
    public func group(_ path: PathComponent..., configure: (RoutesBuilder) throws -> ()) rethrows {
        try configure(HTTPRoutesGroup(root: self, path: path, defaultMaxBodySize: self.defaultMaxBodySize))
    }

    /// Creates a new `Router` with a different default max body size for its routes than the rest of the application.
    ///
    ///     let large = router.group(maxSize: 1_000_000)
    ///     large.post("image", use: self.uploadImage)
    ///
    /// - parameters:
    ///     - defaultMaxBodySize: The maximum number of bytes that a request body can contain in the new group
    ///     `nil` means there is no limit.
    /// - returns: A newly created `Router` with a new max body size.
    public func group(maxSize defaultMaxBodySize: Int?) -> RoutesBuilder {
        return HTTPRoutesGroup(root: self, defaultMaxBodySize: defaultMaxBodySize)
    }

    /// Creates a new `Router` with a different default max body size for its routes than the rest of the application.
    ///
    ///     router.grouped(maxSize: 1_000_000) { large
    ///         large.post("image", use: self.uploadImage)
    ///     }
    ///
    /// - parameters:
    ///     - defaultMaxBodySize: The maximum number of bytes that a request body can contain in the new group
    ///     `nil` means there is no limit.
    ///     - configure: Closure to configure the newly created `Router`.
    ///     - builder: The new builder with the new max body size.
    /// - returns: A newly created `Router` with a new max body size.
    public func grouped(maxSize defaultMaxBodySize: Int?, configure: (_ builder: RoutesBuilder) throws -> ()) rethrows {
        try configure(HTTPRoutesGroup(root: self, defaultMaxBodySize: defaultMaxBodySize))
    }
}

/// Groups routes
private final class HTTPRoutesGroup: RoutesBuilder {
    /// Router to cascade to.
    let root: RoutesBuilder
    
    /// Additional components.
    let path: [PathComponent]

    /// The default max body size for requests in the group.
    let defaultMaxBodySize: Int?

    /// Creates a new `PathGroup`.
    init(root: RoutesBuilder, path: [PathComponent] = [], defaultMaxBodySize: Int? = nil) {
        self.root = root
        self.path = path
        self.defaultMaxBodySize = defaultMaxBodySize
    }
    
    /// See `HTTPRoutesBuilder`.
    func add(_ route: Route) {
        route.path = self.path + route.path
        self.root.add(route)
    }
}
