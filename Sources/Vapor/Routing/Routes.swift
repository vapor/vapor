public final class Routes: RoutesBuilder, CustomStringConvertible {
    public var all: [Route]

    public var description: String {
        return self.all.description
    }
    
    public init() {
        self.all = []
    }
    
    public func add(_ route: Route) {
        self.all.append(route)
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
