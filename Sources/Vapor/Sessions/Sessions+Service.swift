import Sessions
import Cache

extension SessionsMiddleware: Service {
    /// See Service.name
    public static var name: String {
        return "sessions"
    }

    /// See Service.make
    public static func make(for drop: Droplet) throws -> SessionsMiddleware? {
        return try .init(drop.make(SessionsProtocol.self))
    }
}

extension MemorySessions: Service {
    /// See Service.name
    public static var name: String {
        return "memory"
    }

    /// See Service.make
    public static func make(for drop: Droplet) throws -> MemorySessions? {
        return .init()
    }
}

extension CacheSessions: Service {
    /// See Service.name
    public static var name: String {
        return "cache"
    }

    /// See Service.make
    public static func make(for drop: Droplet) throws -> CacheSessions? {
        return try .init(drop.make(CacheProtocol.self))
    }
}
