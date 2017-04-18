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
    public var router: Router

    /// The server that will accept requesting
    /// connections and return the desired
    /// response.
    public var server: ServerFactoryProtocol

    /// Expose to end users to customize driver
    /// Make outgoing requests
    public var client: ClientFactoryProtocol

    /// `Middleware` will be applied in the order
    /// it is set in this array.
    /// 
    /// Make sure to append your custom `Middleware`
    /// if you don't want to overwrite default behavior.
    public var middleware: [Middleware]

    /// Send output and receive input from the console
    /// using the underlying `ConsoleDriver`.
    public var console: ConsoleProtocol

    /// Send informational and error logs.
    /// Defaults to the console.
    public let log: LogProtocol

    /// Provides access to the underlying
    /// `HashProtocol` for hashing data.
    public var hash: HashProtocol

    /// Provides access to the underlying
    /// `CipherProtocol` for encrypting and
    /// decrypting data.
    public var cipher: CipherProtocol

    /// Available Commands to use when starting
    /// the droplet.
    public var commands: [Command]

    /// Render static and templated views.
    public var view: ViewRenderer

    /// Store and retreive key:value
    /// pair information.
    public var cache: CacheProtocol
    
    /// Implemented by your email client
    public var mail: MailProtocol

    /// The providers that have been added.
    public var providers: [Provider]

    /// The responder includes chained middleware
    internal let responder: Responder
    
    /// Storage to add/manage dependencies, identified by a string
    public var storage: [String: Any]
    
    public init(
        _ config: Configs.Config? = nil,
        localization localizationProvided: Localization? = nil,
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
        mail: MailProtocol? = nil,
        providers: [Provider]? = nil
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
        
        // settings
        let environment = config.environment
        let localization: Localization
        do {
            localization = try localizationProvided
                ?? Localization(localizationDirectory: config.localizationDir)
        } catch {
            print("Could not load localization files: \(error)")
            localization = Localization()
        }
        
        // services
        let router = router ?? Router()
        let server = try server ?? config.resolve(ServerFactoryProtocol.self)
        let client = try client ?? config.resolve(ClientFactoryProtocol.self)
        let console = try console ?? config.resolve(ConsoleProtocol.self)
        let log = try log ?? config.resolve(LogProtocol.self)
        let hash = try hash ?? config.resolve(HashProtocol.self)
        let cipher = try cipher ?? config.resolve(CipherProtocol.self)
        let view = try view ?? config.resolve(ViewRenderer.self)
        let cache = try cache ?? config.resolve(CacheProtocol.self)
        let mail = try mail ?? config.resolve(MailProtocol.self)
        let providers = providers ?? config.providers
        
        // service users
        let commands = commands ?? [
            VersionCommand(console),
            RouteList(console, router),
            DumpConfig(console, config)
        ]
        let middleware = try middleware ?? config.resolveArray(Middleware.self)
        
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
        self.providers = providers
        self.responder = middleware.chain(to: router)
        self.storage = [:]
        
        // clear storage
        config.storage = [:]
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
        /// This error is thrown on read timeouts and is providing excess logging of expected behavior.
        /// We will continue to work to resolve the underlying issue associated with this error.
        ///https://github.com/vapor/vapor/issues/678
        if
            case .dispatch(let dispatch) = error,
            let sockets = dispatch as? SocketsError,
            sockets.number == 35
        {
            return
        }

        log.error("Server error: \(error)")
    }
}
