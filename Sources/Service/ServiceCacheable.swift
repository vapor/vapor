/// Capable of caching services
public protocol ServiceCacheable {
    /// The service cache
    var serviceCache: ServiceCache { get }
}

public final class ServiceCache {
    /// The internal services cache.
    private var services: [InterfaceClientIdentifier: ResolvedService]

    /// The internal singletons cache
    internal var singletons: [InterfaceIdentifier: ResolvedService]

    /// Create a new service cache.
    public init() {
        self.services = [:]
        self.singletons = [:]
    }


    /// Gets the cached service if one exists.
    /// - throws if the service was cached as an error
    internal func get<Interface, Client>(
        _ interface: Interface.Type,
        for client: Client.Type
    ) throws -> Interface? {
        let key = InterfaceClientIdentifier(interface: Interface.self, client: Client.self)
        guard let resolved = services[key] else {
            return nil
        }

        return try resolved.resolve() as? Interface
    }

    /// internal method for setting cache based on ResolvedService enum.
    internal func set<Interface, Client>(
        _ resolved: ResolvedService,
        _ interface: Interface.Type,
        for client: Client.Type
    ) {
        let key = InterfaceClientIdentifier(interface: Interface.self, client: Client.self)
        services[key] = resolved
    }


    // MARK: Singleton

    /// Gets the cached service if it is a singleton.
    /// - throws if the service was cached as an error
    internal func getSingleton(
        _ service: Any.Type
    ) throws -> Any? {
        let key = InterfaceIdentifier(interface: service)
        guard let resolved = singletons[key] else {
            return nil
        }

        return try resolved.resolve()
    }

    /// internal method for setting cache based on ResolvedService enum.
    internal func setSingleton(
        _ resolved: ResolvedService,
        type serviceType: Any.Type
    ) {
        let key = InterfaceIdentifier(interface: serviceType)
        singletons[key] = resolved
    }
}

/// a resolved service, either error or the service
internal enum ResolvedService {
    case service(Any)
    case error(Error)

    /// returns the service or throws the error
    internal func resolve() throws -> Any {
        switch self {
        case .error(let error): throw error
        case .service(let service): return service
        }
    }
}

/// hashable struct for an interface type
internal struct InterfaceIdentifier: Hashable {
    static func ==(lhs: InterfaceIdentifier, rhs: InterfaceIdentifier) -> Bool {
        return lhs.interface == rhs.interface
    }

    var hashValue: Int {
        return interface.hashValue
    }

    private let interface: ObjectIdentifier

    public init(interface: Any.Type) {
        self.interface = ObjectIdentifier(interface)
    }
}

/// hashable struct for a client and interface type.
internal struct InterfaceClientIdentifier: Hashable {
    static func ==(lhs: InterfaceClientIdentifier, rhs: InterfaceClientIdentifier) -> Bool {
        return lhs.client == rhs.client && lhs.interface == rhs.interface
    }

    var hashValue: Int {
        return interface.hashValue &+ client.hashValue
    }

    private let interface: ObjectIdentifier
    private let client: ObjectIdentifier

    public init<Interface, Client>(interface: Interface.Type, client: Client.Type) {
        self.interface = ObjectIdentifier(Interface.self)
        self.client = ObjectIdentifier(Client.self)
    }
}
