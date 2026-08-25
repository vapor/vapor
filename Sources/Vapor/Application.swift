public import Configuration
import Logging
#warning("Make this internal")
public import NIOCore
public import NIOConcurrencyHelpers
import NIOPosix
public import ServiceLifecycle
import UnixSignals
#if HTTPClient
import AsyncHTTPClient
#endif

/// Core type representing a Vapor application.
public final class Application: Sendable, Service {
    public var storage: Storage {
        get {
            self._storage.withLockedValue { $0 }
        }
        set {
            self._storage.withLockedValue { $0 = newValue }
        }
    }

    public var didShutdown: Bool {
        self._didShutdown.withLockedValue { $0 }
    }

    public struct Lifecycle: Sendable {
        var handlers: [any LifecycleHandler]
        init() {
            self.handlers = []
        }

        public mutating func use(_ handler: any LifecycleHandler) {
            self.handlers.append(handler)
        }
    }

    public var lifecycle: Lifecycle {
        get {
            self._lifecycle.withLockedValue { $0 }
        }
        set {
            self._lifecycle.withLockedValue { $0 = newValue }
        }
    }

    internal let isBooted: NIOLockedValueBox<Bool>
    public let environment: Environment
    private let _storage: NIOLockedValueBox<Storage>
    private let _didShutdown: NIOLockedValueBox<Bool>
    private let _lifecycle: NIOLockedValueBox<Lifecycle>
    public let sharedAddress: NIOLockedValueBox<SocketAddress?>
    /// Content hashes for advanced ETag comparison, shared by every request.
    package let fileETagHashCache: FileETagHashCache
    private let _services: NIOLockedValueBox<[any Service]>
    public let routes: Routes
    // TODO: inline this when application is a struct
    private let _serverConfiguration: NIOLockedValueBox<ServerConfiguration>
    public var serverConfiguration: ServerConfiguration {
        get {
            self._serverConfiguration.withLockedValue { $0 }
        }
        set {
            self._serverConfiguration.withLockedValue { $0 = newValue }
        }
    }

    /// Configuration reader used to read configuration values.
    ///
    /// You can configure this `ConfigReader` when initializing your ``Application``
    /// to read configuration values from different sources, such as files, environment variables or command line arguments.
    public let configReader: ConfigReader

    // MARK: - Services
    package let contentConfiguration: ContentConfiguration
    package let responder: ServiceOptionType<any Responder>
    public let viewRenderer: any ViewRenderer
    public let directoryConfiguration: DirectoryConfiguration
    public let cache: any Cache
    public let client: any Client

    public struct ServiceConfiguration: Sendable {
        let contentConfiguration: ContentConfiguration
        let viewRenderer: ServiceOptionType<any ViewRenderer>
        let cache: ServiceOptionType<any Cache>
        let responder: ServiceOptionType<any Responder>
        let client: ServiceOptionType<any Client>

        public init(
            contentConfiguration: ContentConfiguration = .default(),
            viewRenderer: ServiceOptionType<any ViewRenderer> = .default,
            cache: ServiceOptionType<any Cache> = .default,
            responder: ServiceOptionType<any Responder> = .default,
            client: ServiceOptionType<any Client> = .default,
        ) {
            self.contentConfiguration = contentConfiguration
            self.viewRenderer = viewRenderer
            self.cache = cache
            self.responder = responder
            self.client = client
        }
    }

    public enum ServiceOptionType<Service: Sendable>: Sendable {
        case `default`
        case provided(Service)
    }

    // MARK: - Initialization

    public convenience init(
        _ environment: Environment? = nil,
        configuration: ServerConfiguration = .init(),
        configReader: ConfigReader = ConfigReader(providers: [CommandLineArgumentsProvider(), EnvironmentVariablesProvider()]),
        services: ServiceConfiguration = .init()
    ) async throws {
        let env = try environment ?? Environment.detect(from: configReader)
        self.init(env, configuration: configuration, configReader: configReader, services: services, internal: true)
        await DotEnvFile.load(for: self.environment)
    }

    // internal flag here is just to stop the compiler from complaining about duplicates
    package init(_ environment: Environment = .development, configuration: ServerConfiguration, configReader: ConfigReader, services: ServiceConfiguration, internal: Bool) {
        self.environment = environment
        self._didShutdown = .init(false)
        self._storage = .init(.init())
        self._lifecycle = .init(.init())
        self.isBooted = .init(false)
        self.contentConfiguration = services.contentConfiguration
        self.directoryConfiguration = .detect()
        self.sharedAddress = .init(nil)
        self.fileETagHashCache = .init(cacheCapacity: configuration.eTagHashCacheCapacity)
        self._services = .init([])
        self._serverConfiguration = .init(configuration)
        self.configReader = configReader

        // Service Setup
        switch services.viewRenderer {
            case .default:
                self.viewRenderer = PlaintextRenderer(viewsDirectory: self.directoryConfiguration.viewsDirectory)
            case .provided(let renderer):
                self.viewRenderer = renderer
        }

        switch services.cache {
            case .default:
                self.cache = MemoryCache()
            case .provided(let cache):
                self.cache = cache
        }

        switch services.client {
        case .default:
            #if HTTPClient
            self.client = VaporHTTPClient(http: HTTPClient.shared, contentConfiguration: self.contentConfiguration)
            #else
            self.client = BlackholeClient(contentConfiguration: self.contentConfiguration)
            #endif
        case .provided(let client):
            self.client = client
        }

        self.responder = services.responder
        self.routes = Routes()
        self.sessions.initialize()
        self.sessions.use(.memory)
        self.servers.initialize()
        self.servers.use(.http)
    }

    /// Register an additional `Service` to run alongside the HTTP server.
    ///
    /// Services are started when `run()` or `start()` is called and shut down
    /// when the application receives a shutdown signal.
    public func addService(_ service: any Service) {
        self._services.withLockedValue { $0.append(service) }
    }

    /// Runs the application as a `Service` (no signal handling).
    ///
    /// Use this when embedding the application in your own `ServiceGroup`:
    /// ```swift
    /// let serviceGroup = ServiceGroup(
    ///     configuration: .init(
    ///         services: [.init(service: app)],
    ///         gracefulShutdownSignals: [.sigterm, .sigint]
    ///     )
    /// )
    /// try await serviceGroup.run()
    /// ```
    ///
    /// Blocks until all services (including the HTTP server) have stopped.
    /// Graceful shutdown is triggered by the parent task or `ServiceGroup`.
    public func run() async throws {
        try await self.boot()
        self.applyAddressConfiguration(AddressConfiguration(from: self.configReader))

        do {
            try await withThrowingDiscardingTaskGroup { group in
                group.addTask { [server = self.server] in
                    try await server.run()
                }
                for service in self._services.withLockedValue({ $0 }) {
                    group.addTask { try await service.run() }
                }
            }
        } catch {
            Logger.current.report(error: error)
            throw error
        }
        try await self.shutdown()
    }

    /// Starts the application as a standalone process with signal handling.
    ///
    /// Registers SIGTERM and SIGINT handlers via `ServiceGroup` and blocks until
    /// a shutdown signal is received. This is the primary entry point for most apps:
    /// ```swift
    /// let app = try await Application()
    /// try routes(app)
    /// try await app.start()
    /// ```
    public func start() async throws {
        try await self.boot()
        self.applyAddressConfiguration(AddressConfiguration(from: self.configReader))

        var services: [ServiceGroupConfiguration.ServiceConfiguration] = []
        services.append(.init(
            service: self.server,
            successTerminationBehavior: .gracefullyShutdownGroup
        ))
        for service in self._services.withLockedValue({ $0 }) {
            services.append(.init(service: service))
        }

        let serviceGroup = ServiceGroup(
            configuration: .init(
                services: services,
                gracefulShutdownSignals: [.sigterm, .sigint],
                logger: Logger.current
            )
        )

        do {
            try await serviceGroup.run()
        } catch {
            Logger.current.report(error: error)
            throw error
        }
        try await self.shutdown()
    }

    /// Called when the applications starts up, will trigger the lifecycle handlers. The asynchronous version of ``boot()``
    public func boot() async throws {
        /// Skip the boot process if already booted
        guard !self.isBooted.withLockedValue({
            var result = true
            swap(&$0, &result)
            return result
        }) else {
            return
        }

        for handler in self.lifecycle.handlers {
            try await handler.willBoot(self)
        }
        for handler in self.lifecycle.handlers {
            try await handler.didBoot(self)
        }
    }

    public func shutdown() async throws {
        guard !self.didShutdown else { return }
        Logger.current.debug("Application shutting down")

        Logger.current.trace("Shutting down providers")
        for handler in self.lifecycle.handlers.reversed()  {
            await handler.shutdown(self)
        }
        self.lifecycle.handlers = []

        Logger.current.trace("Clearing Application storage")
        await self.storage.shutdown()
        self.storage.clear()

        self._didShutdown.withLockedValue { $0 = true }
        Logger.current.trace("Application shutdown complete")
    }

    deinit {
        Logger.current.trace("Application deinitialized, goodbye!")
        assert(self.didShutdown, "Application.shutdown() was not called before Application deinitialized.")
    }
}

public protocol LockKey {}

extension Dictionary {
    fileprivate mutating func insertOrReturn(_ value: @autoclosure () -> Value, at key: Key) -> Value {
        if let existing = self[key] {
            return existing
        }
        let newValue = value()
        self[key] = newValue
        return newValue
    }
}
