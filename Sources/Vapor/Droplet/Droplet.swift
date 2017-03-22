import HTTP
import Console
import Cache
import Sessions
import Crypto
import Transport
import Sockets

public let VERSION = "2.0.0-alpha"

public class Droplet {
    /// The arguments passed to the droplet.
    public let arguments: [String]

    /// The work directory of your droplet is
    /// the directory in which your Resources, Public, etc
    /// folders are stored. This is normally `./` if
    /// you are running Vapor using `.build/xxx/app`
    public let workDir: String

    /// Resources directory relative to workDir
    public var resourcesDir: String {
        return workDir + "Resources/"
    }

    /// Views directory relative to the
    /// resources directory.
    public var viewsDir: String {
        return resourcesDir + "Views/"
    }

    /// The current droplet environment
    public let environment: Environment

    /// Provides access to config settings.
    public let config: Settings.Config

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
    public var server: ServerProtocol.Type

    /// Expose to end users to customize driver
    /// Make outgoing requests
    public var client: ClientProtocol.Type

    /// `Middleware` will be applied in the order
    /// it is set in this array.
    /// 
    /// Make sure to append your custom `Middleware`
    /// if you don't want to overwrite default behavior.
    public var middleware: [Middleware]


    /// Send informational and error logs.
    /// Defaults to the console.
    public var log: LogProtocol

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

    /// Send output and receive input from the console
    /// using the underlying `ConsoleDriver`.
    public var console: ConsoleProtocol

    /// Render static and templated views.
    public var view: ViewRenderer

    /// Store and retreive key:value
    /// pair information.
    public var cache: CacheProtocol

    /// The providers that have been added.
    public internal(set) var providers: [Provider]

    /// Storage to add/manage dependencies, identified by a string
    public var storage: [String: Any]

    /// Implemented by your email client
    public var mail: MailProtocol

    /// The responder will be loaded the first time the droplet is asked
    /// to respond to a request, this prevents having to construct it
    /// for each request
    ///
    /// Loop through middlewares in order, then pass result to router responder
    internal private(set) lazy var responder: Responder = self.middleware.chain(to: self.router)

    /// Initialize the Droplet.
    public init(
        arguments: [String]? = nil,
        workDir workDirProvided: String? = nil,
        environment environmentProvided: Environment? = nil,
        config configProvided: Settings.Config? = nil,
        localization localizationProvided: Localization? = nil,
        log logProvided: LogProtocol? = nil
    ) throws {
        // use arguments provided in init or
        // default to the arguments provided
        // via the command line interface
        let arguments = arguments ?? CommandLine.arguments
        self.arguments = arguments

        let terminal = Terminal(arguments: arguments)
        if let provided = logProvided  {
            self.log = provided
        } else {
            // logging is needed for emitting errors
            self.log = ConsoleLogger(console: terminal)
        }

        // the current droplet environment
        let environment: Environment
        if let provided = environmentProvided {
            environment = provided
        } else {
            environment = CommandLine.environment ?? .development
        }
        self.environment = environment

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

        // use the working directory provided
        // or attempt to find a working directory
        // from the command line arguments or #file.
        let workDir: String
        if let provided = workDirProvided {
            workDir = provided.finished(with: "/")
        } else {
            workDir = Droplet.workingDirectory(from: arguments).finished(with: "/")
        }
        self.workDir = workDir.finished(with: "/")

        // use the config item provided or
        // attempt to create a config from
        // the working directory and arguments
        let config: Settings.Config
        if let provided = configProvided {
            config = provided
        } else {
            do {
                let configDirectory = workDir.finished(with: "/") + "Config/"
                config = try Settings.Config(
                    prioritized: [
                        .commandLine,
                        .directory(root: configDirectory + "secrets"),
                        .directory(root: configDirectory + environment.description),
                        .directory(root: configDirectory)
                    ]
                )
            } catch {
                log.debug("Could not load configuration files: \(error)")
                config = Config([:])
            }
        }
        self.config = config

        // use the provided localization or
        // initialize one from the working directory.
        let localization: Localization
        if let provided = localizationProvided {
            localization = provided
        } else {
            do {
                localization = try Localization(localizationDirectory: workDir + "Localization/")
            } catch {
                log.debug("Could not load localization files: \(error)")
                localization = Localization()
            }
        }
        self.localization = localization

        // DEFAULTS

        router = Router()
        client = EngineClient.self
        server = EngineServer.self
        middleware = []
        console = terminal
        commands = []
        let renderer = StaticViewRenderer(viewsDir: workDir + "Resources/Views")
        if environment == .development {
            // disable cache by default in development
            renderer.cache = nil
        }
        view = renderer
        cache = MemoryCache()
        storage = [:]
        providers = []
        hash = CryptoHasher(hash: .sha1, encoding: .hex)
        cipher = CryptoCipher(
            method: .aes256(.cbc),
            defaultKey: Bytes(repeating: 0, count: 16),
            defaultIV: nil
        )
        mail = UnimplementedMailer()

        // CONFIGURABLE
        addConfigurable(server: EngineServer.self, name: "engine")
        addConfigurable(client: EngineClient.self, name: "engine")
        addConfigurable(console: terminal, name: "terminal")
        addConfigurable(log: log, name: "console")
        try addConfigurable(hash: CryptoHasher.self, name: "crypto")
        try addConfigurable(hash: BCryptHasher.self, name: "bcrypt")
        try addConfigurable(cipher: CryptoCipher.self, name: "crypto")
        addConfigurable(cache: MemoryCache(), name: "memory")
        addConfigurable(middleware: SessionsMiddleware(MemorySessions()), name: "sessions")
        addConfigurable(middleware: DateMiddleware(), name: "date")
        addConfigurable(middleware: TypeSafeErrorMiddleware(), name: "type-safe")
        addConfigurable(middleware: FileMiddleware(publicDir: workDir + "Public/"), name: "file")
        addConfigurable(middleware: HeadMiddleware(), name: "head")
        let contentTypeLogger = ContentTypeLogger { [weak self] log in
            if let welf = self {
                welf.log.info(log)
            } else {
                print(log)
            }
        }
        addConfigurable(middleware: contentTypeLogger, name: "content-type-log")

        if config["droplet", "middleware"]?.array == nil {
            // if no configuration has been supplied
            // apply all middleware
            middleware = [
                SessionsMiddleware(MemorySessions()),
                DateMiddleware(),
                TypeSafeErrorMiddleware(),
                FileMiddleware(publicDir: workDir + "Public/"),
                HeadMiddleware(),
                contentTypeLogger,
            ]
            log.debug("No `middleware` key in `droplet.json` found, using default middleware.")
        }

        // Post Init Defaults
        commands.append(RouteList(self))
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
