import HTTP
import Console
import Cache
import Sessions
import Crypto
import Transport
import Sockets

public let VERSION = "2.0.0-beta"

public class Droplet {
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
        _ config: Configs.Config? = nil,
        localization localizationProvided: Localization? = nil,
        commands: [Command]? = nil
    ) throws {
        var config = try config ?? Config()
        
        // port override
        if let port = config.arguments.value(for: "port")?.int {
            try config.set("server.port", port)
        }
        
        // configurable
        try config.addConfigurable(ServerFactory<EngineServer>(), name: "engine")
        try config.addConfigurable(ClientFactory<EngineClient>(), name: "engine")
        try config.addConfigurable(Terminal(arguments: []), name: "terminal")
        try config.addConfigurable({ config in
            return try ConsoleLogger(config.resolve(ConsoleProtocol.self))
        }, name: "console")
        try config.addConfigurable({ config in
            return StaticViewRenderer(viewsDir: config.viewsDir)
        }, name: "static")
        try config.addConfigurable(CryptoHasher.self, name: "crypto")
        try config.addConfigurable(BCryptHasher.self, name: "bcrypt")
        try config.addConfigurable(CryptoCipher.self, name: "crypto")
        try config.addConfigurable(MemoryCache(), name: "memory")
        try config.addConfigurable({ config in
            return try ErrorMiddleware(config.environment, config.resolve(LogProtocol.self))
        }, name: "error")
        try config.addConfigurable(SessionsMiddleware(MemorySessions()), name: "sessions")
        try config.addConfigurable(DateMiddleware(), name: "date")
        try config.addConfigurable({ config in
            return FileMiddleware(publicDir: config.workDir + "Public/")
        }, name: "file")
        
        // services
        let router = Router()
        let server = try config.resolve(ServerFactoryProtocol.self)
        let client = try config.resolve(ClientFactoryProtocol.self)
        let console = try config.resolve(ConsoleProtocol.self)
        let log = try config.resolve(LogProtocol.self)
        let hash = try config.resolve(HashProtocol.self)
        let cipher = try config.resolve(CipherProtocol.self)
        let view = try config.resolve(ViewRenderer.self)
        let cache = try config.resolve(CacheProtocol.self)
        let mail = try config.resolve(MailProtocol.self)
        
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
        
        let middleware = try config.resolveArray(Middleware.self)
        
        
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
        let commands = try commands ?? [
            VersionCommand(console),
            RouteList(console, router),
            DumpConfig(console, config),
            Serve(console, server, responder, log, config.makeServerConfig())
        ]
        
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
    
    func serverErrors(error: ServerError) {

    }
}
