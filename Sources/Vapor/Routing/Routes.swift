public final class Routes: RoutesBuilder {
    public var routes: [Route]
    public var eventLoop: EventLoop
    
    public init(eventLoop: EventLoop) {
        self.routes = []
        self.eventLoop = eventLoop
    }
    
    public func add(_ route: Route) {
        self.routes.append(route)
    }
}
