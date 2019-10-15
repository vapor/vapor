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
    var factories: [ServiceID: Any]
    var extensions: [ServiceID: [Any]]
    var providers: [Provider]

    // MARK: Init

    /// Creates a new `Services`.
    public init() {
        self.factories = [:]
        self.extensions = [:]
        self.providers = []
    }

    // MARK: CustomStringConvertible

    /// See `CustomStringConvertible`.
    public var description: String {
        var desc: [String] = []

        desc.append("Services:")
        if factories.isEmpty {
            desc.append("<none>")
        } else {
            for (id, _) in self.factories {
                desc.append("- \(id.type)")
            }
        }

        desc.append("Providers:")
        if providers.isEmpty {
            desc.append("- none")
        } else {
            for provider in self.providers {
                desc.append("- \(type(of: provider))")
            }
        }

        return desc.joined(separator: "\n")
    }
}

extension Application {
    // MARK: Services

    /// Registers a `Provider` to the services. This will automatically register all of the `Provider`'s available
    /// services. It will also store the provider so that its lifecycle methods can be called later.
    ///
    ///     try app.register(PrintLoggerProvider())
    ///
    /// See `Provider` for more information.
    ///
    /// - parameters:
    ///     - provider: Initialized `Provider` to register.
    /// - throws: The provider can throw errors while registering services.
    public func provider<P>(_ provider: P) where P: Provider {
        guard !self.providers.contains(where: { Swift.type(of: $0) == P.self }) else {
            return
        }
        provider.register(self)
        self.services.providers.append(provider)
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
    public func register<S>(instance: S) {
        return self.register(instance: S.self, instance)
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
    public func register<S>(instance interface: S.Type, _ instance: S) {
        let id = ServiceID(S.self)
        let factory = ServiceFactory(cache: .none, boot: { c in
            return instance
        }, shutdown: { service in
            // do nothing
        })
        self.services.factories[id] = factory
    }

    public func register<S>(
        singleton interface: S.Type,
        _ closure: @escaping (Application) throws -> (S)
    ) {
        return self.register(singleton: S.self, boot: closure, shutdown: { _ in })
    }

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
    ///     let app: Application ...
    ///     try app.make(Counter.self).count += 1
    ///     try app.make(Counter.self).count += 1
    ///     try print(app.make(Counter.self).count) // 2
    ///
    /// - warning: Storing references to `Container` from a singleton service will
    ///            create a reference cycle.
    ///
    /// - parameters:
    ///     - interface: Service type.
    ///     - boot: Creates an instance of the service type using the container to locate
    ///                any required dependencies.
    ///     - shutdown: Cleans up the created service.
    public func register<S>(
        singleton interface: S.Type,
        boot: @escaping (Application) throws -> (S),
        shutdown: @escaping (S) throws -> ()
    ) {
        let id = ServiceID(S.self)
        let factory = ServiceFactory(cache: .application, boot: boot, shutdown: shutdown)
        self.services.factories[id] = factory
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
    public func register<S>(_ interface: S.Type, _ factory: @escaping (Application) throws -> (S)) {
        let id = ServiceID(S.self)
        let factory = ServiceFactory(cache: .none, boot: { c in
            return try factory(c)
        }, shutdown: { service in
            // do nothing
        })
        self.services.factories[id] = factory
    }
    
    /// Adds a supplement closure for the given Service type
    public func extend<S>(_ service: S.Type, _ closure: @escaping (inout S, Application) throws -> Void) {
        let id = ServiceID(S.self)
        let ext = ServiceExtension<S>(closure: closure)
        self.services.extensions[id, default: []].append(ext)
    }
}
