extension Router {
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
    public func grouped(_ path: PathComponentsRepresentable...) -> Router {
        return PathGroup(root: self, components: path.convertToPathComponents())
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
    public func group(_ path: PathComponentsRepresentable..., configure: (Router) -> ()) {
        configure(PathGroup(root: self, components: path.convertToPathComponents()))
    }
}

// MARK: Private

/// Groups routes
private final class PathGroup: Router {
    /// See `Router`.
    var routes: [Route<Responder>] {
        return root.routes
    }

    /// Router to cascade to.
    let root: Router

    /// Additional components.
    let components: [PathComponent]
    
    /// Creates a new `PathGroup`.
    init(root router: Router, components: [PathComponent]) {
        self.root = router
        self.components = components
    }

    /// See `Router`.
    func register(route: Route<Responder>) {
        // insert _after_ the method
        route.path.insert(contentsOf: components, at: 1)
        root.register(route: route)
    }

    /// See `Router`.
    func route(request: Request) -> Responder? {
        return root.route(request: request)
    }
}
