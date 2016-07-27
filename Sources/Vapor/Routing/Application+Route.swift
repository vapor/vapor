import Engine

/**
    Any type that conforms to this protocol
    can be passed as a requirement to Vapor's
    type-safe route calls.
*/
public protocol StringInitializable {
    init?(from string: String) throws
}

///Allow the Int type to be a type-safe routing parameter
extension Int: StringInitializable {
    public init?(from string: String) throws {
        guard let int = Int(string) else {
            return nil
        }

        self = int
    }
}

///Allow the String type to be a type-safe routing parameter
extension String: StringInitializable {
    public init?(from string: String) throws {
        self = string
    }
}

extension Droplet {
    /**
        Creates a route for all HTTP methods.
        `get`, `post`, `put`, `patch`, and `delete`.
    */
    public final func any(_ path: String, handler: Route.Handler) {
        self.get(path, handler: handler)
        self.post(path, handler: handler)
        self.put(path, handler: handler)
        self.patch(path, handler: handler)
        self.delete(path, handler: handler)
    }

    /**
        Creates standard Create, Read, Update, Delete routes
        using the Handlers from a supplied `ResourceController`.

        Note: You are responsible for pluralizing your endpoints.
    */
    public final func resource<R: Resource>(
        _ path: String,
        makeControllerWith controllerFactory: () -> R
    ) {
        // GET /entities
        self.get(path) { request in
            return try controllerFactory().index(request: request)
        }

        // POST /entities
        self.post(path) { request in
            return try controllerFactory().store(request: request)
        }

        // GET /entities/:id
        self.get(path, R.Item.self) { request, item in
            return try controllerFactory().show(request: request, item: item)
        }

        // PUT /entities/:id
        self.put(path, R.Item.self) { request, item in
            return try controllerFactory().replace(request: request, item: item)
        }

        // DELETE /entities
        self.delete(path) { request in
            return try controllerFactory().destroy(request: request)
        }

        // DELETE /entities/:id
        self.delete(path, R.Item.self) { request, item in
            return try controllerFactory().destroy(request: request, item: item)
        }

        // PATCH /entities/:id
        self.patch(path, R.Item.self) { request, item in
            return try controllerFactory().modify(request: request, item:item)
        }

        // OPTIONS /entities
        self.options(path) { request in
            let response = try controllerFactory().options(request: request).makeResponse(for: request)
            response.headers["Allow"] = "GET,POST,DELETE,OPTIONS"
            return response
        }

        // OPTIONS /entities/:id
        self.options(path, R.Item.self) { request, item in
            let response = try controllerFactory().options(request: request, item: item).makeResponse(for: request)
            response.headers["Allow"] = "GET,POST,PUT,PATCH,DELETE,OPTIONS"
            return response
        }
    }

    public final func resource<R: Resource>(
        _ path: String,
        _ resources: R) {
        resource(path) {
            return resources
        }
    }

    /**
        Add resource controller for specified path

        - parameter path: path associated w/ resource controller
        - parameter controller: controller type to use
     */
    public final func resource<
        R: Resource
        where R: DropletInitializable
    >(
        _ path: String,
        _ controller: R.Type
    ) {
        resource(path) {
            return controller.init(droplet: self)
        }
    }

    /**
     Add resource controller for specified path

     - parameter path: path associated w/ resource controller
     - parameter controller: controller type to use
     */
    public final func resource<
        R: Resource
        where R: DefaultInitializable>(
        _ path: String,
        _ controller: R.Type
    ) {
        resource(path) {
            return controller.init()
        }
    }

    /**
        Adds a route handled by a type that can be initialized with an `Droplet`.
        This method is useful if you have a controller and would like to add an action
        that is not a common REST action.

        Here's an example of how you would add a route with this method:

        ```drop.add(.get, path: "/foo", action: TestController.foo)```

        - parameter method: The `Request.Method` that the action should be executed for.
        - parameter path: The HTTP path that the action can run at.
        - parameter action: The curried action to run on the provided type.
     */
    public final func add<ActionController: DropletInitializable>(
        _ method: HTTPMethod,
        path: String,
        action: (ActionController) -> (HTTPRequest) throws -> HTTPResponseRepresentable) {
        add(method, path: path, action: action) {
            ActionController(droplet: self)
        }
    }

    /**
         Adds a route handled by a type that can be defaultly initialized.
         This method is useful if you have a controller and would like to add an action
         that is not a common REST action.

         Here's an example of how you would add a route with this method:

         ```drop.add(.get, path: "/bar", action: TestController.bar)```

         - parameter method: The `Request.Method` that the action should be executed for.
         - parameter path: The HTTP path that the action can run at.
         - parameter action: The curried action to run on the provided type.
     */
    public final func add<ActionController: DefaultInitializable>(
        _ method: HTTPMethod,
        path: String,
        action: (ActionController) -> (HTTPRequest) throws -> HTTPResponseRepresentable) {
        add(method, path: path, action: action) {
            ActionController()
        }
    }

    /**
        Adds a route handled by a type that can be initialized via the provided factory.
        This method is useful if you have a controller and would like to add an action
        that is not a common REST action, and you need to handle initialization yourself.

        Here's an example of how you would add a route with this method:

        ```drop.add(.get, path: "/baz", action: TestController.baz) { TestController() }```

        - parameter method: The `Request.Method` that the action should be executed for.
        - parameter path: The HTTP path that the action can run at.
        - parameter action: The curried action to run on the provided type.
        - parameter factory: The closure to instantiate the controller type.
     */
    public final func add<ActionController>(
        _ method: HTTPMethod,
        path: String,
        action: (ActionController) -> (HTTPRequest) throws -> HTTPResponseRepresentable,
        makeControllerWith factory: () throws -> ActionController) {
        add(method, path: path) { request in
            let controller = try factory()
            return try action(controller)(request).makeResponse(for: request)
        }
    }
}
