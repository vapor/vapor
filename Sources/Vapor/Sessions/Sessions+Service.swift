import Sessions
import Cache
import Service
import HTTP

extension SessionsMiddleware: ServiceType {
    /// See Service.name
    public static var serviceName: String {
        return "sessions"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [Middleware.self]
    }

    /// See Service.make
    public static func makeService(for container: Container) throws -> SessionsMiddleware? {
        return try .init(container.make(SessionsProtocol.self))
    }
}

extension MemorySessions: ServiceType {
    /// See Service.name
    public static var serviceName: String {
        return "memory"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [SessionsProtocol.self]
    }

    /// See Service.make
    public static func makeService(for container: Container) throws -> MemorySessions? {
        return .init()
    }
}

extension CacheSessions: ServiceType {
    /// See Service.name
    public static var serviceName: String {
        return "cache"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [SessionsProtocol.self]
    }

    /// See Service.make
    public static func makeService(for container: Container) throws -> CacheSessions? {
        return try .init(container.make(CacheProtocol.self))
    }
}
