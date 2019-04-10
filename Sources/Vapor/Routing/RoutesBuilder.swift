public protocol RoutesBuilder {
    var eventLoop: EventLoop { get }
    func add(_ route: Route)
}
