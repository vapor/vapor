public import Configuration
import Logging
import NIOConcurrencyHelpers
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

    // MARK: - Public Properties
    /// The environment the application is running in
    public let environment: Environment

    /// The routes registered to the application
    public let routes: Routes

    /// Configuration reader used to read configuration values.
    ///
    /// You can configure this `ConfigReader` when initializing your ``Application``
    /// to read configuration values from different sources, such as files, environment variables or command line arguments.
    public let configReader: ConfigReader

    /// The ``ViewRenderer`` configured in the application
    public let viewRenderer: any ViewRenderer

    /// The directory information the app is running in
    public let directoryConfiguration: DirectoryConfiguration

    /// The ``Cache`` configured in the application
    public let cache: any Cache

    /// The ``Client`` configured in the application
    public let client: any Client

    /// The ``SessionDriver`` configured in the application
    public let sessionDriver: any SessionDriver

    // MARK: - Freezable Types
    private let _middlewares: FreezableType<Middlewares>
    private let _serverConfiguration: FreezableType<ServerConfiguration>
    private let _services: FreezableType<[any Service]>
    private let _lifecycleHandlers: FreezableType<[ any LifecycleHandler]>

    // MARK: - Other Types

    /// Content hashes for advanced ETag comparison, shared by every request.
    package let fileETagHashCache: FileETagHashCache
    internal let isBooted: NIOLockedValueBox<Bool>
    private let _storage: NIOLockedValueBox<Storage>
    private let _didShutdown: NIOLockedValueBox<Bool>
    package let contentConfiguration: ContentConfiguration
    package let responder: ServiceOptionType<any Responder>
    let sessionsConfiguration: SessionsConfiguration

    // MARK: - Services

    public struct ServiceConfiguration: Sendable {
        let contentConfiguration: ContentConfiguration
        let viewRenderer: ServiceOptionType<any ViewRenderer>
        let cache: ServiceOptionType<any Cache>
        let responder: ServiceOptionType<any Responder>
        let client: ServiceOptionType<any Client>
        let sessionDriver: ServiceOptionType<any SessionDriver>
        let sessionsConfiguration: SessionsConfiguration

        public init(
            contentConfiguration: ContentConfiguration = .default(),
            viewRenderer: ServiceOptionType<any ViewRenderer> = .default,
            cache: ServiceOptionType<any Cache> = .default,
            responder: ServiceOptionType<any Responder> = .default,
            client: ServiceOptionType<any Client> = .default,
            sessionDriver: ServiceOptionType<any SessionDriver> = .default,
            sessionsConfiguration: SessionsConfiguration = .default()
        ) {
            self.contentConfiguration = contentConfiguration
            self.viewRenderer = viewRenderer
            self.cache = cache
            self.responder = responder
            self.client = client
            self.sessionDriver = sessionDriver
            self.sessionsConfiguration = sessionsConfiguration
        }
    }

    public enum ServiceOptionType<Service: Sendable>: Sendable {
        case `default`
        case provided(Service)
    }

    // MARK: - Initialization
    public init(
        _ environment: Environment? = nil,
        configuration: ServerConfiguration = .init(),
        configReader: ConfigReader = ConfigReader(providers: [CommandLineArgumentsProvider(), EnvironmentVariablesProvider()]),
        services: ServiceConfiguration = .init()
    ) async throws {
        let environment = try environment ?? Environment.detect(from: configReader)
        self.environment = environment
        self._didShutdown = .init(false)
        self._storage = .init(.init())
        self._lifecycleHandlers = .init([], name: "Lifecycle Handlers")
        self.isBooted = .init(false)
        self.contentConfiguration = services.contentConfiguration
        self.directoryConfiguration = .detect()
        self.fileETagHashCache = .init(capacity: configuration.eTagHashCacheCapacity)
        self._services = .init([], name: "Services")
        self._serverConfiguration = .init(configuration, name: "Configuration")
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

        switch services.sessionDriver {
        case .default:
            self.sessionDriver = MemorySessions(storage: .init())
        case .provided(let service):
            self.sessionDriver = service
        }

        self.sessionsConfiguration = services.sessionsConfiguration
        self.responder = services.responder
        self._middlewares = .init(Self.defaultMiddlewares(environment: environment), name: "Middlewares")
        self.routes = Routes()
        self.servers.initialize()
        self.servers.use(.http)

        #warning("Can we remove all this?")
        await DotEnvFile.load(for: self.environment)
    }

    // MARK: - Execution
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
        try await self.withLifecycle {
            try await withThrowingDiscardingTaskGroup { group in
                group.addTask { [server = self.server] in
                    try await server.run()
                }
                for service in self._services.value {
                    group.addTask { try await service.run() }
                }
            }
        }
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
        try await self.withLifecycle {
            var services: [ServiceGroupConfiguration.ServiceConfiguration] = []
            services.append(.init(
                service: self.server,
                successTerminationBehavior: .gracefullyShutdownGroup
            ))
            for service in self._services.value {
                services.append(.init(service: service))
            }

            let serviceGroup = ServiceGroup(
                configuration: .init(
                    services: services,
                    gracefulShutdownSignals: [.sigterm, .sigint],
                    logger: Logger.current
                )
            )
            try await serviceGroup.run()
        }
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

        for handler in self._lifecycleHandlers.value {
            try await handler.willBoot(self)
        }
        for handler in self._lifecycleHandlers.value {
            try await handler.didBoot(self)
        }
    }

    public func shutdown() async throws {
        guard !self.didShutdown else { return }
        Logger.current.debug("Application shutting down")

        Logger.current.trace("Shutting down providers")
        for handler in self._lifecycleHandlers.value.reversed()  {
            await handler.shutdown(self)
        }

        Logger.current.trace("Clearing Application storage")
        await self.storage.shutdown()
        self.storage.clear()

        self._didShutdown.withLockedValue { $0 = true }
        Logger.current.trace("Application shutdown complete")
    }

    private func withLifecycle(_ runServices: () async throws -> Void) async throws {
        do {
            try await self.boot()
            freezeApplication()
            self.applyAddressConfiguration(AddressConfiguration(from: self.configReader))
            try await runServices()
        } catch {
            Logger.current.report(error: error)
            try? await self.shutdown()
            throw error
        }
        try await self.shutdown()
    }

    // MARK: - Freezable Type Configuration

    /// Register an additional `Service` to run alongside the HTTP server.
    ///
    /// Services are started when `run()` or `start()` is called and shut down
    /// when the application receives a shutdown signal.
    public func addService(_ service: any Service) {
        self._services.withValue { $0.append(service) }
    }

    /// Register a ``LifecycleHandler`` with the application. Vapor will call the
    /// different lifecycle events when they are reached
    public func addLifecycleHandler(_ lifecycleHander: any LifecycleHandler) {
        self._lifecycleHandlers.withValue { $0.append(lifecycleHander) }
    }

    private func freezeApplication() {
        self._lifecycleHandlers.freeze()
        self._services.freeze()
        self._middlewares.freeze()
    }

    deinit {
        Logger.current.trace("Application deinitialized, goodbye!")
        assert(self.didShutdown, "Application.shutdown() was not called before Application deinitialized.")
    }
}

// MARK: - Freezable types
extension Application {
    public var middleware: Middlewares {
        get {
            self._middlewares.value
        }
        set {
            self._middlewares.withValue { $0 = newValue }
        }
    }

    public var serverConfiguration: ServerConfiguration {
        get {
            self._serverConfiguration.value
        }
        set {
            self._serverConfiguration.withValue { $0 = newValue }
        }
    }
}
