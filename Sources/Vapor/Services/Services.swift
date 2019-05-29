/// The `Services` struct is used for registering and storing a `Container`'s services.
///
/// # Registering Services
///
/// While the `Services` struct is mutable (before it is used to initialize a `Container`), new services
/// can be registered using a few different methods.
///
/// ## Factory
///
/// The most common method for registering services is by using a factory.
///
///     services.register(Logger.self) { container in
///         return PrintLogger()
///     }
///
/// This will ensure a new instance of your service is created for any `SubContainer`s. See the `register(_:factory:)`
/// methods for more information.
///
/// - note: You may need to disambiguate the closure return by adding `-> T`.
///
/// ## Type
///
/// A concise method for registering services is by using the `ServiceType` protocol. Types conforming
/// to this protocol can be registered to `Services` using just the type name.
///
///     extension PrintLogger: ServiceType { ... }
///
///     services.register(PrintLogger.self)
///
/// See `ServiceType` for more details.
///
/// ## Instance
///
/// You can also register pre-initialized instances of a service.
///
///     services.register(PrintLogger())
///
/// - warning: When used with reference types (classes), this method will share the same
///            object with all `SubContainer`s. Be careful to avoid race conditions.
///
/// # Making Services
///
/// Once you initialize a `Container` from a `Services` struct, the `Services` will become immutable.
/// After this point, you can use the `make(_:)` method on `Container` to start creating services.
///
/// - note: The `Services` are immutable on a `Container` to optimize caching.
///
/// See `Container` for more information.
public struct Services: CustomStringConvertible {
    /// All registered services.
    var factories: [ServiceID: Any]

    /// All registered service providers. These are stored so that their lifecycle methods can be called later.
    var providers: [Provider]
    
    var extensions: [ServiceID: [Any]]

    // MARK: Init

    /// Creates a new `Services`.
    public init() {
        self.factories = [:]
        self.providers = []
        self.extensions = [:]
    }

    // MARK: Instance
    
    /// Registers a pre-initialized instance of a `Service` conforming to a single interface to the `Services`.
    ///
    ///     services.register(PrintLogger(), as: Logger.self)
    ///
    /// - warning: When used with reference types (classes), this method will share the same
    ///            object with all subcontainers. Be careful to avoid race conditions.
    ///
    /// - parameters:
    ///     - instance: Pre-initialized `Service` instance to register.
    ///     - interface: An interface that this `Service` supports (besides its own type).
    public mutating func instance<S>(_ instance: S) {
        return self.instance(S.self, instance)
    }

    /// Registers a pre-initialized instance of a `Service` conforming to a single interface to the `Services`.
    ///
    ///     services.register(PrintLogger(), as: Logger.self)
    ///
    /// - warning: When used with reference types (classes), this method will share the same
    ///            object with all subcontainers. Be careful to avoid race conditions.
    ///
    /// - parameters:
    ///     - instance: Pre-initialized `Service` instance to register.
    ///     - interface: An interface that this `Service` supports (besides its own type).
    public mutating func instance<S>(_ interface: S.Type, _ instance: S) {
        let id = ServiceID(S.self)
        let factory = ServiceFactory(isSingleton: false) { c in
            return instance
        }
        self.factories[id] = factory
    }
    
    // MARK: Factory

    /// Registers a new singleton service. Singleton services are created only once per container.
    ///
    /// Classes and structs registered via the singleton method will only have their factory
    /// closures called once per container.
    ///
    /// Registering a `class` via the singleton method allows for storing state on a `Container`:
    ///
    ///     final class Counter {
    ///         var count: Int
    ///         init() {
    ///             self.count = 0
    ///         }
    ///     }
    ///
    ///     s.singleton(Counter.self) { c in
    ///         return .init()
    ///     }
    ///
    ///     let c: Container ...
    ///     try c.make(Counter.self).count += 1
    ///     try c.make(Counter.self).count += 1
    ///     try print(c.make(Counter.self).count) // 2
    ///
    /// - warning: Storing references to `Container` from a singleton service will
    ///            create a reference cycle.
    ///
    /// - parameters:
    ///     - interface: Service type.
    ///     - factory: Creates an instance of the service type using the container to locate
    ///                any required dependencies.
    public mutating func singleton<S>(_ interface: S.Type, _ factory: @escaping (Container) throws -> (S)) {
        let id = ServiceID(S.self)
        let factory = ServiceFactory(isSingleton: true) { c in
            return try factory(c)
        }
        self.factories[id] = factory
    }

    /// Registers a `Service` creating closure (service factory) conforming to a single interface to the `Services`.
    ///
    ///     services.register(Logger.self) { container in
    ///         return PrintLogger()
    ///     }
    ///
    /// This is the most common method for registering services as it ensures a new instance of the `Service` is
    /// initialized for each sub-container. It also provides access to the `Container` when the `Service` is initialized
    /// making it easy to query the `Container` for dependencies.
    ///
    ///     services.register(Cache.self) { container in
    ///         return try RedisCache(connection: container.make())
    ///     }
    ///
    /// See the other `register(_:factory:)` method that can accept zero or more interfaces.
    ///
    /// - parameters:
    ///     - interfaces: Zero or more interfaces that this `Service` supports (besides its own type).
    ///     - factory: `Container` accepting closure that returns an initialized instance of this `Service`.
    public mutating func register<S>(_ interface: S.Type, _ factory: @escaping (Container) throws -> (S)) {
        let id = ServiceID(S.self)
        let factory = ServiceFactory(isSingleton: false) { c in
            return try factory(c)
        }
        self.factories[id] = factory
    }

    // MARK: Provider

    /// Registers a `Provider` to the services. This will automatically register all of the `Provider`'s available
    /// services. It will also store the provider so that its lifecycle methods can be called later.
    ///
    ///     try services.register(PrintLoggerProvider())
    ///
    /// See `Provider` for more information.
    ///
    /// - parameters:
    ///     - provider: Initialized `Provider` to register.
    /// - throws: The provider can throw errors while registering services.
    public mutating func provider<P>(_ provider: P) where P: Provider {
        guard !providers.contains(where: { Swift.type(of: $0) == P.self }) else {
            return
        }
        provider.register(&self)
        providers.append(provider)
    }
    
    // MARK: Extend
    
    /// Adds a supplement closure for the given Service type
    public mutating func extend<S>(_ service: S.Type, _ closure: @escaping (inout S, Container) throws -> Void) {
        let id = ServiceID(S.self)
        let ext = ServiceExtension<S>(closure: closure)
        self.extensions[id, default: []].append(ext)
    }


    // MARK: CustomStringConvertible

    /// See `CustomStringConvertible`.
    public var description: String {
        var desc: [String] = []

        desc.append("Services:")
        if factories.isEmpty {
            desc.append("<none>")
        } else {
            for (id, _) in factories {
                desc.append("- \(id.type)")
            }
        }

        desc.append("Providers:")
        if providers.isEmpty {
            desc.append("- none")
        } else {
            for provider in providers {
                desc.append("- \(type(of: provider))")
            }
        }

        return desc.joined(separator: "\n")
    }
}
