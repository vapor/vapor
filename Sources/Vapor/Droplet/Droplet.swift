import HTTP
import Console
import Cache
import Sessions
import HMAC
import Cipher
import Fluent
import Transport

public let VERSION = "1.0.2"

public class Droplet {
    /**
     The arguments passed to the droplet.
     */
    public let arguments: [String]

    /**
        The work directory of your droplet is
        the directory in which your Resources, Public, etc
        folders are stored. This is normally `./` if
        you are running Vapor using `.build/xxx/drop`
    */
    public let workDir: String

    /**
        Resources directory relative to workDir
    */
    public var resourcesDir: String {
        return workDir + "Resources/"
    }

    /**
        Views directory relative to the
        resources directory.
    */
    public var viewsDir: String {
        return resourcesDir + "Views/"
    }

    /**
        The current droplet environment
    */
    public let environment: Environment

    /**
        Provides access to config settings.
    */
    public let config: Settings.Config

    /**
        Provides access to language specific
        strings and defaults.
    */
    public let localization: Localization


    /**
        The router driver is responsible
        for returning registered `Route` handlers
        for a given request.
    */
    public var router: Router

    /**
        The server that will accept requesting
        connections and return the desired
        response.
    */
    public var server: ServerProtocol.Type

    /**
        Expose to end users to customize driver
        Make outgoing requests
    */
    public var client: ClientProtocol.Type

    /**
        `Middleware` will be applied in the order
        it is set in this array.

        Make sure to append your custom `Middleware`
        if you don't want to overwrite default behavior.
    */
    public var middleware: [Middleware]


    /**
        Send informational and error logs.
        Defaults to the console.
     */
    public var log: LogProtocol

    /**
        Provides access to the underlying
        `HashProtocol` for hashing data.
    */
    public var hash: HashProtocol

    /**
        Provides access to the underlying
        `CipherProtocol` for encrypting and
        decrypting data.
    */
    public var cipher: CipherProtocol


    /**
        Available Commands to use when starting
        the droplet.
    */
    public var commands: [Command]

    /**
         Send output and receive input from the console
         using the underlying `ConsoleDriver`.
    */
    public var console: ConsoleProtocol

    /**
        Render static and templated views.
    */
    public var view: ViewRenderer

    /**
        Store and retreive key:value
        pair information.
    */
    public var cache: CacheProtocol

    /**
        The Database for this Droplet
        to run preparations on, if supplied.
    */
    public var database: Database?

    /**
        Preparations for using the database.
    */
    public var preparations: [Preparation.Type]

    /**
        Storage to add/manage dependencies, identified by a string
    */
    public var storage: [String: Any]

    /**
        The providers that have been added.
    */
    public internal(set) var providers: [Provider]

    /**
        Initialize the Droplet.
    */
    public init(
        arguments: [String]? = nil,
        workDir workDirProvided: String? = nil,
        environment environmentProvided: Environment? = nil,
        config configProvided: Settings.Config? = nil,
        localization localizationProvided: Localization? = nil
    ) {
        // use arguments provided in init or
        // default to the arguments provided
        // via the command line interface
        let arguments = arguments ?? CommandLine.arguments
        self.arguments = arguments

        // logging is needed for emitting errors
        let terminal = Terminal(arguments: arguments)
        let log = ConsoleLogger(console: terminal)

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
            terminal.output("Production mode enabled, disabling informational logs.", style: .info)
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
        server = Server<TCPServerStream, Parser<Request>, Serializer<Response>>.self
        client = Client<TCPClientStream, Serializer<Request>, Parser<Response>>.self
        middleware = []
        self.log = log
        console = terminal
        commands = []
        view = LeafRenderer(viewsDir: workDir + "Resources/Views")
        cache = MemoryCache()
        database = nil
        storage = [:]
        preparations = []
        providers = []

        do {
            hash = try CryptoHasher(config: config)
        } catch {
            hash = CryptoHasher(method: .sha1, defaultKey: [])
            log.debug("Could not configure hash, using default: \(error)")
        }

        do {
            cipher = try CryptoCipher(config: config)
        } catch {
            cipher = CryptoCipher(
                method: .chacha20,
                defaultKey: Bytes(repeating: 0, count: 32),
                defaultIV: Bytes(repeating: 0, count: 8)
            )
            log.debug("Could not configure cipher, using default: \(error)")
        }

        // CONFIGURABLE

        addConfigurable(server: Server<TCPServerStream, Parser<Request>, Serializer<Response>>.self, name: "engine")
        addConfigurable(client: Client<TCPClientStream, Serializer<Request>, Parser<Response>>.self, name: "engine")
        addConfigurable(console: terminal, name: "terminal")
        addConfigurable(log: log, name: "console")
        addConfigurable(hash: CryptoHasher.self, name: "crypto")
        addConfigurable(cipher: CryptoCipher.self, name: "crypto")

        if config["middleware", "server"]?.array == nil && config["droplet", "middleware", "server"]?.array == nil {
            // if no configuration has been supplied
            // apply all middleware
            middleware = [
                SessionsMiddleware(sessions: MemorySessions()),
                AbortMiddleware(),
                DateMiddleware(),
                TypeSafeErrorMiddleware(),
                ValidationMiddleware(),
                FileMiddleware(workDir: workDir),
            ]
            log.debug("No `middleware.server` key in `droplet.json` found, using default middleware.")
        } else {
            // add all configurable middleware
            addConfigurable(middleware: SessionsMiddleware(sessions: MemorySessions()), name: "sessions")
            addConfigurable(middleware: AbortMiddleware(), name: "abort")
            addConfigurable(middleware: DateMiddleware(), name: "date")
            addConfigurable(middleware: TypeSafeErrorMiddleware(), name: "type-safe")
            addConfigurable(middleware: ValidationMiddleware(), name: "validation")
            addConfigurable(middleware: FileMiddleware(workDir: workDir), name: "file")
        }

        // hook into all providers after init
        for provider in providers {
            provider.afterInit(self)
        }
    }

    func serverErrors(error: ServerError) {
        log.error("Server error: \(error)")
    }
}
