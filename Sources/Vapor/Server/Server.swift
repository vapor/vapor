public protocol Server {
    func start(hostname: String?, port: Int?) throws
    var onShutdown: EventLoopFuture<Void> { get }
    func shutdown()
}
