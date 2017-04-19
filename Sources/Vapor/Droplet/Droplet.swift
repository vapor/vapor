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
    public let config: Configs.Config

    /// Provides access to language specific
    /// strings and defaults.
    public let localization: Localization

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
    public var commands: [Command]

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
    
    public init(
        config: Configs.Config?,
        localization localizationProvided: Localization?
    ) throws {
        var config = try config ?? Config()
        
        // port override
        if let port = config.arguments.value(for: "port")?.int {
            try config.set("server.port", port)
        }
        
        // configurable
        config.addConfigurable(server: EngineServer.self, name: "engine")
        config.addConfigurable(client: EngineClient.self, name: "engine")
        config.addConfigurable(log: ConsoleLogger.self, name: "console")
        config.addConfigurable(console: Terminal.self, name: "terminal")
        config.addConfigurable(view: StaticViewRenderer.self, name: "static")
        config.addConfigurable(hash: CryptoHasher.self, name: "crypto")
        config.addConfigurable(hash: BCryptHasher.self, name: "bcrypt")
        config.addConfigurable(cipher: CryptoCipher.self, name: "crypto")
        config.addConfigurable(cache: MemoryCache.self, name: "memory")
        config.addConfigurable(middleware: ErrorMiddleware.self, name: "error")
        config.addConfigurable(sessions: MemorySessions.self, name: "memory")
        config.addConfigurable(sessions: CacheSessions.self, name: "cache")
        config.addConfigurable(middleware: SessionsMiddleware.self, name: "sessions")
        config.addConfigurable(middleware: DateMiddleware.self, name: "date")
        config.addConfigurable(middleware: FileMiddleware.self, name: "file")
        
        // services
        let router = Router()
        let server = try config.resolveServer()
        let client = try config.resolveClient()
        let console = try config.resolveConsole()
        let log = try config.resolveLog()
        let hash = try config.resolveHash()
        let cipher = try config.resolveCipher()
        let view = try config.resolveView()
        let cache = try config.resolveCache()
        let mail = try config.resolveMail()
        
        // settings
        let environment = config.environment
        let localization: Localization
        do {
            localization = try localizationProvided
                ?? Localization(localizationDirectory: config.localizationDir)
        } catch {
            log.debug("Could not load localization files: \(error)")
            localization = Localization()
        }
        
        let middleware = try config.resolveMiddleware()
        
        
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
            Serve(console, server, responder, log, config.makeServerConfig())
        ]
        let commands = try config.resolveCommands() + requiredCommands
        
        // set
        self.localization = localization
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
        if environment == .development {
            // disable cache by default in development
            self.view.shouldCache = false
        }
        
        // boot providers
        for provider in config.providers {
            try provider.boot(self)
        }
    }
}

// MARK: Inits

extension Droplet: ConfigInitializable {
    public convenience init(config: Configs.Config) throws {
        try self.init(config: config, localization: nil)
    }
    
    public convenience init(_ config: Configs.Config) throws {
        try self.init(config: config, localization: nil)
    }
    
    public convenience init() throws {
        try self.init(config: nil, localization: nil)
    }
}
