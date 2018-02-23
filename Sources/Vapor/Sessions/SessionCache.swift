internal final class SessionCache {
    var middlewareFlag: Bool
    var session: Session?

    init(session: Session? = nil) {
        self.session = session
        middlewareFlag = false
    }
}

extension SessionCache: ServiceType {
    /// See `ServiceType.serviceIsSingleton`
    static var serviceIsSingleton: Bool { return true }

    /// See `ServiceType.makeService`
    static func makeService(for worker: Container) throws -> SessionCache {
        return .init()
    }
}
