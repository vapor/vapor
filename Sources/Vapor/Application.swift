import ConsoleKit
import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOPosix
import ServiceLifecycle
import AsyncHTTPClient

/// Core type representing a Vapor application.
public final class Application: Sendable, Service {
    public var environment: Environment {
        get {
            self._environment.withLockedValue { $0 }
        }
        set {
            self._environment.withLockedValue { $0 = newValue }
        }
    }
    
    public var storage: Storage {
        get {
            self._storage.withLockedValue { $0 }
        }
        set {
            self._storage.withLockedValue { $0 = newValue }
        }
    }

    public var logger: Logger {
        get {
            self._logger.withLockedValue { $0 }
        }
        set {
            self._logger.withLockedValue { $0 = newValue }
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
    
    public final class Locks: Sendable {
        public let main: NIOLock
        // Is there a type we can use to make this Sendable but reuse the existing lock we already have?
        private let storage: NIOLockedValueBox<[ObjectIdentifier: NIOLock]>
        
        init() {
            self.main = .init()
            self.storage = .init([:])
        }
        
        public func lock<Key>(for key: Key.Type) -> NIOLock
        where Key: LockKey {
            self.main.withLock {
                self.storage.withLockedValue {
                    $0.insertOrReturn(.init(), at: .init(Key.self))
                }
            }
        }
    }
    
    public var locks: Locks {
        get {
            self._locks.withLockedValue { $0 }
        }
        set {
            self._locks.withLockedValue { $0 = newValue }
        }
    }
    
    public var sync: NIOLock {
        self.locks.main
    }
    
    public enum EventLoopGroupProvider: Sendable {
        case shared(any EventLoopGroup)
        public static var singleton: EventLoopGroupProvider {
            .shared(MultiThreadedEventLoopGroup.singleton)
        }
    }
    
    public let eventLoopGroupProvider: EventLoopGroupProvider
    public let eventLoopGroup: any EventLoopGroup
    internal let isBooted: NIOLockedValueBox<Bool>
    private let _environment: NIOLockedValueBox<Environment>
    private let _storage: NIOLockedValueBox<Storage>
    private let _didShutdown: NIOLockedValueBox<Bool>
    private let _logger: NIOLockedValueBox<Logger>
    private let _lifecycle: NIOLockedValueBox<Lifecycle>
    private let _locks: NIOLockedValueBox<Locks>
    public let sharedNewAddress: NIOLockedValueBox<SocketAddress?>
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

    // MARK: - Services
    package let contentConfiguration: ContentConfiguration
    package let responder: ServiceOptionType<any Responder>
    public let byteBufferAllocator: ByteBufferAllocator = .init()
    public let viewRenderer: any ViewRenderer
    public let directoryConfiguration: DirectoryConfiguration
    public let passwordHasher: any PasswordHasher
    public let cache: any Cache
    public let client: any Client

    public struct ServiceConfiguration {
        let contentConfiguration: ContentConfiguration
        let viewRenderer: ServiceOptionType<any ViewRenderer>
        let passwordHasher: ServiceOptionType<any PasswordHasher>
        let cache: ServiceOptionType<any Cache>
        let responder: ServiceOptionType<any Responder>
        let client: ServiceOptionType<any Client>
        let logger: ServiceOptionType<Logger>

        public init(
            contentConfiguration: ContentConfiguration = .default(),
            viewRenderer: ServiceOptionType<any ViewRenderer> = .default,
            passwordHasher: ServiceOptionType<any PasswordHasher> = .default,
            cache: ServiceOptionType<any Cache> = .default,
            responder: ServiceOptionType<any Responder> = .default,
            client: ServiceOptionType<any Client> = .default,
            logger: ServiceOptionType<Logger> = .default
        ) {
            self.contentConfiguration = contentConfiguration
            self.viewRenderer = viewRenderer
            self.passwordHasher = passwordHasher
            self.cache = cache
            self.responder = responder
            self.client = client
            self.logger = logger
        }
    }

    public enum ServiceOptionType<Service: Sendable>: Sendable {
        case `default`
        case provided(Service)
    }

    public struct ServerConfiguration: Sendable {
        public var address: BindAddress

        // Closure to run when the server is running - useful for grabbing
        // information such as the port
        public var onServerRunning: @Sendable (_ channel: any Channel) async -> ()
        public var reportMetrics = true

        public init(address: BindAddress, onServerRunning: @Sendable @escaping (_ channel: any Channel) async -> ()) {
            self.address = address
            self.onServerRunning = onServerRunning
        }

        /// Host name the server will bind to.
        public var hostname: String? {
            get {
                switch address {
                case .hostname(let hostname, _):
                    return hostname
                default:
                    return nil
                }
            }
            set {
                if let newValue {
                    switch address {
                    case .hostname(_, let port):
                        address = .hostname(newValue, port: port)
                    default:
                        address = .hostname(newValue)
                    }
                }
            }
        }

        /// Port the server will bind to.
        public var port: Int? {
            get {
                switch address {
                case .hostname(_, let port):
                    port
                default:
                    nil
                }
            }
            set {
                if let newValue {
                    switch address {
                    case .hostname(let hostname, _):
                        address = .hostname(hostname, port: newValue)
                    default:
                        address = .hostname(port: newValue)
                    }
                }
            }
        }

        /// A human-readable description of the configured address. Used in log messages when starting server.
        var addressDescription: String {
            #warning("Bring back")
//            let scheme = tlsConfiguration == nil ? "http" : "https"
            let scheme = "https"
            switch address {
            case .hostname(let hostname, let port):
                return "\(scheme)://\(hostname):\(port)"
            case .unixDomainSocket(let socketPath):
                return "\(scheme)+unix: \(socketPath)"
            }
        }
    }

    // MARK: - Initialization

    public convenience init(
        _ environment: Environment = .development,
        _ eventLoopGroupProvider: EventLoopGroupProvider = .singleton,
        configuration: ServerConfiguration = .init(address: .hostname("127.0.0.1", port: 8080), onServerRunning: { _ in }),
        services: ServiceConfiguration = .init()
    ) async throws {
        self.init(environment, eventLoopGroupProvider, configuration: configuration, services: services, internal: true)
        await self.asyncCommands.use(self.servers.command, as: "serve", isDefault: true)
        await DotEnvFile.load(for: self.environment, logger: self.logger)
    }
    
    // internal flag here is just to stop the compiler from complaining about duplicates
    package init(_ environment: Environment = .development, _ eventLoopGroupProvider: EventLoopGroupProvider = .singleton, configuration: ServerConfiguration, services: ServiceConfiguration, internal: Bool) {
        self._environment = .init(environment)
        self.eventLoopGroupProvider = eventLoopGroupProvider
        switch eventLoopGroupProvider {
        case .shared(let group):
            self.eventLoopGroup = group
        }

        let logger: Logger
        switch services.logger {
        case .default:
            logger = Logger(label: "codes.vapor.application")
        case .provided(let customLogger):
            logger = customLogger
        }

        self._locks = .init(.init())
        self._didShutdown = .init(false)
        self._storage = .init(.init(logger: logger))
        self._lifecycle = .init(.init())
        self.isBooted = .init(false)
        self.contentConfiguration = services.contentConfiguration
        self.directoryConfiguration = .detect()
        self.sharedNewAddress = .init(nil)
        self._serverConfiguration = .init(configuration)

        // Service Setup
        switch services.viewRenderer {
            case .default:
                self.viewRenderer = PlaintextRenderer(viewsDirectory: self.directoryConfiguration.viewsDirectory, logger: logger)
            case .provided(let renderer):
                self.viewRenderer = renderer
        }

        switch services.passwordHasher {
            case .default:
            #if bcrypt
                self.passwordHasher = BcryptHasher()
            #else
                self.passwordHasher = PlaintextHasher()
            #endif
            case .provided(let hasher):
                self.passwordHasher = hasher
        }

        switch services.cache {
            case .default:
                self.cache = MemoryCache()
            case .provided(let cache):
                self.cache = cache
        }

        switch services.client {
        case .default:
            self.client = VaporHTTPClient(http: HTTPClient.shared, logger: logger, byteBufferAllocator: self.byteBufferAllocator, contentConfiguration: self.contentConfiguration)
        case .provided(let client):
            self.client = client
        }

        self.responder = services.responder
        self.routes = Routes()
        self._logger = .init(logger)

        self.core.initialize()
        self.sessions.initialize()
        self.sessions.use(.memory)
        self.servers.initialize()
        self.servers.use(.httpNew)
        self.asyncCommands.use(RoutesCommand(), as: "routes")
    }
    
    /// Starts the ``Application`` asynchronous using the ``startup()`` method, then waits for any running tasks
    /// to complete. If your application is started without arguments, the default argument is used.
    ///
    /// Under normal circumstances, ``execute()`` runs until a shutdown is triggered, then wait for the web server to
    /// (manually) shut down before returning.
    public func run() async throws {
        do {
            try await self.startup()
            try await self.running?.onStop.get()
        } catch {
            self.logger.report(error: error)
            throw error
        }
    }
    
    /// When called, this will asynchronously execute the startup command provided through an argument. If no startup
    /// command is provided, the default is used. Under normal circumstances, this will start running Vapor's webserver.
    ///
    /// If you start Vapor through this method, you'll need to prevent your Swift Executable from closing yourself.
    /// If you want to run your ``Application`` indefinitely, or until your code shuts the application down,
    /// use ``execute()`` instead.
    public func startup() async throws {
        try await self.boot()

        let combinedCommands = AsyncCommands(
            commands: self.asyncCommands.commands.merging(self.commands.commands) { $1 },
            defaultCommand: self.asyncCommands.defaultCommand ?? self.commands.defaultCommand,
            enableAutocomplete: self.asyncCommands.enableAutocomplete || self.commands.enableAutocomplete
        ).group()

        var context = CommandContext(console: self.console, input: self.environment.commandInput)
        context.application = self
        try await self.console.run(combinedCommands, with: context)
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
        assert(!self.didShutdown, "Application has already shut down")
        self.logger.debug("Application shutting down")

        self.logger.trace("Shutting down providers")
        for handler in self.lifecycle.handlers.reversed()  {
            await handler.shutdown(self)
        }
        self.lifecycle.handlers = []

        self.logger.trace("Clearing Application storage")
        await self.storage.shutdown()
        self.storage.clear()

        switch self.eventLoopGroupProvider {
        case .shared:
            self.logger.trace("Running on shared EventLoopGroup. Not shutting down EventLoopGroup.")
        }

        self._didShutdown.withLockedValue { $0 = true }
        self.logger.trace("Application shutdown complete")
    }

    deinit {
        self.logger.trace("Application deinitialized, goodbye!")
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
