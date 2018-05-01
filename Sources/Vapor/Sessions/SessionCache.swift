internal final class SessionCache: ServiceType {
    /// See `ServiceType`.
    static func makeService(for worker: Container) throws -> SessionCache {
        return .init()
    }

    var middlewareFlag: Bool
    var session: Session?

    init(session: Session? = nil) {
        self.session = session
        middlewareFlag = false
    }
}
