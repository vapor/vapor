public protocol Server {
    var onShutdown: EventLoopFuture<Void> { get }
    func start(hostname: String?, port: Int?) throws
    func shutdown()
}

extension Server {
    public func start() throws {
        try self.start(hostname: nil, port: nil)
    }
}
