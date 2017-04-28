import HTTP
import Console
import Cache
import Sessions
import Crypto
import Transport
import Sockets

public let VERSION = "2.0.0-beta"

public final class Droplet {
    /// Provides access to config settings.
    public let config: Config

    /// The router driver is responsible
    /// for returning registered `Route` handlers
    /// for a given request.
    public let router: Router

    /// The server that will accept requesting
    /// connections and return the desired
    /// response.
    public let server: ServerFactoryProtocol

    /// Expose to end users to customize driver
    /// Make outgoing requests
    public let client: ClientFactoryProtocol

    /// `Middleware` will be applied in the order
    /// it is set in this array.
    /// 
    /// Make sure to append your custom `Middleware`
    /// if you don't want to overwrite default behavior.
    public let middleware: [Middleware]

    /// Send output and receive input from the console
    /// using the underlying `ConsoleDriver`.
    public let console: ConsoleProtocol

    /// Send informational and error logs.
    /// Defaults to the console.
    public let log: LogProtocol

    /// Provides access to the underlying
    /// `HashProtocol` for hashing data.
    public let hash: HashProtocol

    /// Provides access to the underlying
    /// `CipherProtocol` for encrypting and
    /// decrypting data.
    public let cipher: CipherProtocol

    /// Available Commands to use when starting
    /// the droplet.
    public let commands: [Command]

    /// Render static and templated views.
    public let view: ViewRenderer

    /// Store and retreive key:value
    /// pair information.
    public let cache: CacheProtocol
    
    /// Implemented by your email client
    public let mail: MailProtocol

    /// The responder includes chained middleware
    internal let responder: Responder
    
    /// Storage to add/manage dependencies, identified by a string
    public var storage: [String: Any]

    /// Creates a Droplet.
    public init(
        config: Config? = nil,
        router: Router? = nil,
        server: ServerFactoryProtocol? = nil,
        client: ClientFactoryProtocol? = nil,
        middleware: [Middleware]? = nil,
        console: ConsoleProtocol? = nil,
        log: LogProtocol? = nil,
        hash: HashProtocol? = nil,
        cipher: CipherProtocol? = nil,
        commands: [Command]? = nil,
        view: ViewRenderer? = nil,
        cache: CacheProtocol? = nil,
        mail: MailProtocol? = nil
    ) throws {
        var config = try config ?? Config()
        

        config.addConfigurable(server: EngineServer.self, name: "engine")
        config.addConfigurable(client: EngineClient.self, name: "engine")
        config.addConfigurable(log: ConsoleLogger.init, name: "console")
        config.addConfigurable(console: Terminal.init, name: "terminal")
        config.addConfigurable(view: StaticViewRenderer.init, name: "static")
        config.addConfigurable(hash: CryptoHasher.init, name: "crypto")
        config.addConfigurable(hash: BCryptHasher.init, name: "bcrypt")
        config.addConfigurable(cipher: CryptoCipher.init, name: "crypto")
        config.addConfigurable(cache: MemoryCache.init, name: "memory")
        config.addConfigurable(middleware: ErrorMiddleware.init, name: "error")
        config.addConfigurable(sessions: MemorySessions.init, name: "memory")
        config.addConfigurable(sessions: CacheSessions.init, name: "cache")
        config.addConfigurable(middleware: SessionsMiddleware.init, name: "sessions")
        config.addConfigurable(middleware: DateMiddleware.init, name: "date")
        config.addConfigurable(middleware: FileMiddleware.init, name: "file")
        config.addConfigurable(middleware: CORSMiddleware.init, name: "cors")

        // port override
        if let port = config.arguments.value(for: "port")?.int {
            try config.set("server.port", port)
        }

        let router = router ?? Router()
        let server = try server ?? config.resolveServer()
        let client = try client ?? config.resolveClient()
        let console = try console ?? config.resolveConsole()
        let log = try log ?? config.resolveLog()
        let hash = try hash ?? config.resolveHash()
        let cipher = try cipher ?? config.resolveCipher()
        let view = try view ?? config.resolveView()
        let cache = try cache ?? config.resolveCache()
        let mail = try mail ?? config.resolveMail()

        // settings
        let environment = config.environment
        let middleware = try middleware ?? config.resolveMiddleware()

        let chain = middleware.chain(to: router)
        let responder = Request.Handler { request in
            log.info("\(request.method) \(request.uri.path)")

            let isHead = request.method == .head
            if isHead {
                /// The HEAD method is identical to GET.
                ///
                /// https://tools.ietf.org/html/rfc2616#section-9.4
                request.method = .get
            }

            let response: Response
            do {
                response = try chain.respond(to: request)
            } catch {
                log.error("Uncaught error: \(type(of: error))")
                log.error(error)
                log.info("Use `ErrorMiddleware` or catch \(type(of: error)) to provide a better error response.")
                response = Response(status: .internalServerError)
            }

            if isHead {
                /// The server MUST NOT return a message-body in the response for HEAD.
                ///
                /// https://tools.ietf.org/html/rfc2616#section-9.4
                response.body = .data([])
            }

            return response
        }

        // commands
        let requiredCommands: [Command] = try [
            VersionCommand(console),
            RouteList(console, router),
            DumpConfig(console, config),
            Serve(console, server, responder, log, config.makeServerConfig()),
            ProviderInstall(
                console,
                config.providers,
                publicDir: config.publicDir,
                viewsDir: config.viewsDir
            )
        ]
        let commands = try (commands ?? config.resolveCommands())
            + requiredCommands

        // set
        self.router = router
        self.server = server
        self.client = client
        self.middleware = middleware
        self.console = console
        self.log = log
        self.hash = hash
        self.cipher = cipher
        self.commands = commands
        self.view = view
        self.cache = cache
        self.mail = mail
        self.responder = responder
        self.storage = [:]

        // set config
        self.config = config

        // post init
        // change logging based on env
        switch environment {
        case .production:
            log.info("Production mode enabled, disabling informational logs.")
            log.enabled = [.error, .fatal]
        case .development:
            log.enabled = [.info, .warning, .error, .fatal]
        default:
            log.enabled = LogLevel.all
        }
        
        // disable cache by default during development
        self.view.shouldCache = environment == .production

        // boot providers
        for provider in config.providers {
            try provider.boot(self)
        }
    }
}

// MARK: Convenience

extension Droplet {
    /// Creates a Droplet using the supplied Config.
    public convenience init(_ config: Config) throws {
        try self.init(config: config)
    }
}
