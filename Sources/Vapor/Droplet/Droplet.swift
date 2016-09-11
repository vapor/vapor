import Foundation
import Socks
import HTTP
import Console
import Fluent
import Transport
import Cache
import Settings
import Sessions

public let VERSION = "0.17.0"

public class Droplet {
    /**
        The router driver is responsible
        for returning registered `Route` handlers
        for a given request.
    */
    public let router: Router

    /**
        The server that will accept requesting
        connections and return the desired
        response.
    */
    public let server: ServerProtocol.Type

    /**
        Provides access to config settings.
    */
    public let config: Settings.Config
    
    /**
        Storage to add/manage dependencies, identified by a string
    */
    public var storage: [String: Any]

    /**
        Provides access to language specific
        strings and defaults.
    */
    public let localization: Localization

    /**
        Provides access to the underlying
        `HashDriver`.
    */
    public let hash: Hash

    /**
        The work directory of your droplet is
        the directory in which your Resources, Public, etc
        folders are stored. This is normally `./` if
        you are running Vapor using `.build/xxx/drop`
    */
    public let workDir: String

    /**
        `Middleware` will be applied in the order
        it is set in this array.

        Make sure to append your custom `Middleware`
        if you don't want to overwrite default behavior.
     */
    public let enabledMiddleware: [Middleware]


    /**
        Middleware that is available to this Droplet,
        but may not be enabled by configuration.
    */
    public let availableMiddleware: [String: Middleware]

    /**
        Available Commands to use when starting
        the droplet.
    */
    public var commands: [Command]

    /**
         Send output and receive input from the console
         using the underlying `ConsoleDriver`.
    */
    public let console: ConsoleProtocol


    /**
        Send informational and error logs.
        Defaults to the console.
    */
    public let log: Log

    /**
        Render static and templated views.
    */
    public let view: ViewRenderer

    /**
        Expose to end users to customize driver
        Make outgoing requests
    */
    public let client: ClientProtocol.Type

    /**
        Store and retreive key:value
        pair information.
    */
    public let cache: CacheProtocol

    /**
        Resources directory relative to workDir
    */
    public var resourcesDir: String {
        return workDir + "Resources/"
    }

    /**
        The arguments passed to the droplet.
    */
    public let arguments: [String]

    /**
        The Database for this Droplet
        to run preparations on, if supplied.
    */
    public let database: Database?

    /**
        All of the providers supplied to the droplet.
    */
    public let providers: [Provider]

    /**
        The current droplet environment
    */
    public let environment: Environment

    /**
        Initialize the Droplet.
    */
    public init(
        // non-providable
        arguments: [String]? = nil,
        workDir workDirProvided: String? = nil,
        environment environmentProvided: Environment? = nil,
        config configProvided: Settings.Config? = nil,
        localization localizationProvided: Localization? = nil,

        // providable
        server: ServerProtocol.Type? = nil,
        hash: Hash? = nil,
        console: ConsoleProtocol? = nil,
        log: Log? = nil,
        view: ViewRenderer? = nil,
        client: ClientProtocol.Type? = nil,
        database: Database? = nil,
        cache: CacheProtocol? = nil,

        // middlewarefl
        availableMiddleware: [String: Middleware]? = nil,
        serverMiddleware: [String]? = nil,
        clientMiddleware: [String]? = nil,

        // database preparations
        preparations: [Preparation.Type] = [],

        // providers
        providers providerTypes: [Provider.Type] = [],
        initializedProviders: [Provider] = []
    ) {
        // back log warnings and errors until logs are initialized
        var logs: [(level: LogLevel, message: String)] = []

        // use arguments provided in init or
        // default to the arguments provided
        // via the command line interface
        let arguments = arguments ?? CommandLine.arguments
        self.arguments = arguments

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

        // the current droplet environment
        let environment: Environment
        if let provided = environmentProvided {
            environment = provided
        } else {
            environment = CommandLine.environment ?? .development
        }
        self.environment = environment

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
                logs.append((.error, "Could not load configuration files: \(error)"))
                config = Config([:])
            }
        }
        self.config = config

        // create an array of all providers
        // using both the providers passed as
        // instances and those that are ConfigInitializable.
        var providers: [Provider] = []
        providers += initializedProviders
        for providerType in providerTypes {
            do {
                let provider = try providerType.init(config: config)
                providers.append(provider)
            } catch {
                logs.append((.error, "Could not initialize provider \(providerType): \(error)"))
            }
        }
        self.providers = providers

        // default available middleware
        var am: [String: Middleware] = [
            "file": FileMiddleware(workDir: workDir),
            "validation": ValidationMiddleware(),
            "date": DateMiddleware(),
            "type-safe": TypeSafeErrorMiddleware(),
            "abort": AbortMiddleware(),
            "sessions": SessionsMiddleware(sessions: MemorySessions())
        ]

        // combine with the supplied available
        // middleware from the init
        if let avail = availableMiddleware {
            for (name, m) in avail {
                am[name] = m
            }
        }

        // account for all types provided
        // to the droplet's init method
        var provided = Providable(
            server: server,
            hash: hash,
            console: console,
            log: log,
            view: view,
            client: client,
            database: database,
            cache: cache,
            middleware: am
        )

        // extract a single providable struct
        // by merging all providers together
        for provider in providers {
            do {
                provided = try provided.merged(with: provider.provided)
            } catch ProvidableError.overwritten(let type) {
                logs.append((.warning,"\(provider.name) attempted to overwrite \(type)."))
            } catch {
                logs.append((.error, "\(error)"))
            }
        }

        // use the provided console or
        // or default to the terminal
        let console = provided.console ?? Terminal(arguments: arguments)
        self.console = console

        // use the provided logger or
        // default to a logger that uses the console.
        let log = provided.log ?? ConsoleLogger(console: console)
        self.log = log

        // iterate through any logs that were emitted
        // before the instance of Log was created.
        for item in logs {
            log.log(item.level, message: item.message, file: #file, function: #function, line: #line)
        }

        self.view = provided.view ?? LeafRenderer(viewsDir: workDir + "Resources/Views")

        // use the provided localization or 
        // initialize one from the working directory.
        let localization: Localization
        if let provided = localizationProvided {
            localization = provided
        } else {
            do {
                localization = try Localization(workingDirectory: workDir)
            } catch {
                log.error("Could not load localization files: \(error)")
                localization = Localization()
            }
        }
        self.localization = localization

        // set the hashing key to the key
        // from the configuration files or nothing.
        let key = config["app", "key"]?.string
        // initialize the hash from one provided
        // or use a default SHA2 hasher
        let hash = provided.hash ?? SHA2Hasher(variant: .sha256, defaultKey: key)
        self.hash = hash

        // middleware contains all avail middleware
        // supplied from defaults, init, or providers
        let middleware = provided.middleware ?? [:]
        self.availableMiddleware = middleware

        // create array of enabled middleware
        var serverEnabledMiddleware: [Middleware] = []

        if let enabled = serverMiddleware {
            // add all middleware specified
            // by enabledMiddleware init arg
            for name in enabled {
                if let m = middleware[name] {
                    serverEnabledMiddleware.append(m)
                }
            }
        } else if let array = config["middleware", "server"]?.array {
            // add all middleware specified by
            // config files
            for item in array {
                if let name = item.string, let m = middleware[name] {
                    serverEnabledMiddleware.append(m)
                }
            }
        } else {
            // if not config was supplied,
            // use whatever middlewares were
            // provided
            serverEnabledMiddleware = Array(middleware.values)
        }

        self.enabledMiddleware = serverEnabledMiddleware.reversed()



        var clientEnabledMiddleware: [Middleware] = []

        if let enabled = clientMiddleware {
            for name in enabled {
                if let m = middleware[name] {
                    clientEnabledMiddleware.append(m)
                }
            }
        } else if let array = config["middleware", "client"]?.array {
            for item in array {
                if let name = item.string, let m = middleware[name] {
                    clientEnabledMiddleware.append(m)
                }
            }
        } else {
            clientEnabledMiddleware = []
        }

        let client = provided.client ?? Client<TCPClientStream, Serializer<Request>, Parser<Response>>.self
        self.client = client

        client.defaultMiddleware = clientEnabledMiddleware

        // set the router, server, and client
        // from provided or defaults.
        self.router = Router()
        self.server = provided.server ?? Server<TCPServerStream, Parser<Request>, Serializer<Response>>.self

        // misc arrays and other stored properties
        storage = [:]
        commands = []

        // iterate over preparations to set the
        // supplied database on the models
        if let database = provided.database {
            for preparation in preparations {
            	// casting the type to `Entity.Type` instead
                // of `Model.Type` in order to catch all
                // `Model` types as well as `Pivot` generics
                if let entity = preparation as? Entity.Type {
                    entity.database = database
                }
            }
            self.database = database
        } else {
            self.database = nil
        }

        // provided cache, fluent, or memory as a backup
        if let cache = provided.cache {
            self.cache = cache
        } else if let database = provided.database {
            self.cache = FluentCache(database: database)
        } else {
            self.cache = MemoryCache()
        }

        // the prepare command will run all
        // of the supplied preparations on the database.
        let prepare = Prepare(console: console, preparations: preparations, database: self.database)

        // the serve command will boot the servers
        // and always runs the prepare command
        let serve = Serve(console: console, prepare: prepare) {
            try self.bootServers()
        }

        // the version command prints the frameworks version.
        let version = VersionCommand(console: console)

        // adds the commands
        commands.append(serve)
        commands.append(prepare)
        commands.append(version)

        // prepare for production mode
        if environment == .production {
            console.output("Production mode enabled, disabling informational logs.", style: .info)
            log.enabled = [.error, .fatal]
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
