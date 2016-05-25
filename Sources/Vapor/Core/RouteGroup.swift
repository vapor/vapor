extension Route {
    public struct Group {
        public let parent: RouteGrouper
        public let leadingPath: String
        public let scopedMiddleware: [Middleware]
    }
}

extension Route.Group: RouteGrouper {
    public func add(middleware: [Middleware],
                    method: Request.Method,
                    path: String,
                    handler: Route.Handler) {
        parent.add(middleware: self.scopedMiddleware + middleware,
                   method: method,
                   path: leadingPath.finish("/") + path,
                   handler: handler)
    }
}
