public final class Routes: RoutesBuilder, CustomStringConvertible {
    public var routes: [Route]

    public var description: String {
        return self.routes.description
    }
    
    public init() {
        self.routes = []
    }
    
    public func add(_ route: Route) {
        self.routes.append(route)
    }
}

extension Application: RoutesBuilder {
    public func add(_ route: Route) {
        self.routes.add(route)
    }
    
    public var routes: Routes {
        return self.make()
    }
}
