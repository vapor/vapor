/// Capable of caching services
public protocol ServiceCacheable {
    /// The service cache
    var serviceCache: ServiceCache { get }
}

public final class ServiceCache {
    /// The internal storage.
    internal var storage: [InterfaceClientPair: ResolvedService]

    /// Create a new service cache.
    public init() {
        self.storage = [:]
    }

    /// Sets the resolved service in the cache.
    public func set<Interface, Client>(
        _ interface: Interface,
        for client: Client.Type
    ) {
        self.set(resolved: .service(interface), Interface.self, for: Client.self)
    }

    /// Sets an error instead of a service in the cache.
    public func set<Interface, Client>(
        error: Error,
        _ interface: Interface.Type,
        for client: Client.Type
    ) {
        self.set(resolved: .error(error), Interface.self, for: Client.self)
    }

    /// internal method for setting cache based on ResolvedService enum.
    private func set<Interface, Client>(
        resolved: ResolvedService,
        _ interface: Interface.Type,
        for client: Client.Type
    ) {
        let key = InterfaceClientPair(interface: Interface.self, client: Client.self)
        storage[key] = resolved
    }

    /// Gets the cached service if one exists.
    /// - throws if the service was cached as an error
    public func get<Interface, Client>(
        _ interface: Interface.Type,
        for client: Client.Type
    ) throws -> Interface? {
        let key = InterfaceClientPair(interface: Interface.self, client: Client.self)
        guard let resolved = storage[key] else {
            return nil
        }

        switch resolved {
        case .error(let err): throw err
        case .service(let service): return service as? Interface
        }
    }
}

internal enum ResolvedService {
    case service(Any)
    case error(Error)

    internal func resolve() throws -> Any {
        switch self {
        case .error(let error): throw error
        case .service(let service): return service
        }
    }
}

struct InterfaceClientPair: Hashable {
    static func ==(lhs: InterfaceClientPair, rhs: InterfaceClientPair) -> Bool {
        return lhs.client == rhs.client && lhs.client == rhs.client
    }

    var hashValue: Int {
        return interface.hashValue & client.hashValue
    }

    private let interface: ObjectIdentifier
    private let client: ObjectIdentifier

    public init<Interface, Client>(interface: Interface.Type, client: Client.Type) {
        self.interface = ObjectIdentifier(Interface.self)
        self.client = ObjectIdentifier(Client.self)
    }
}
