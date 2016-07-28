import Foundation
import Socks
import Engine
import Console
import Fluent

public let VERSION = "0.15.0"

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
    public let server: Server.Type

    /**
        The session driver is responsible for
        storing and reading values written to the
        users session.
    */
    public let sessions: Sessions

    /**
        Provides access to config settings.
    */
    public let config: Config
    
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
    public var globalMiddleware: [Middleware]

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
        Expose to end users to customize driver
        Make outgoing requests
    */
    public let client: Client.Type

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
        The routes registered.
    */
    public var routes: [Route]

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
        Initialize the Droplet.
    */
    public init(
        // non-providable
        arguments: [String]? = nil,
        workDir workDirProvided: String? = nil,
        config configProvided: Config? = nil,
        localization localizationProvided: Localization? = nil,

        // providable
        server: Server.Type? = nil,
        router: Router? = nil,
        sessions: Sessions? = nil,
        hash: Hash? = nil,
        console: ConsoleProtocol? = nil,
        log: Log? = nil,
        client: Client.Type? = nil,
        database: Database? = nil,

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
        let arguments = arguments ?? ProcessInfo.arguments()
        self.arguments = arguments

        // use the working directory provided
        // or attempt to find a working directory
        // from the command line arguments or #file.
        let workDir: String
        if let provided = workDirProvided {
            workDir = provided
        } else {
            workDir = Droplet.workingDirectory(from: arguments)
        }
        self.workDir = workDir

        // use the config item provided or
        // attempt to create a config from
        // the working directory and arguments
        let config: Config
        if let provided = configProvided {
            config = provided
        } else {
            do {
                config = try Config(workingDirectory: workDir, arguments: arguments)
            } catch {
                logs.append((.error, "Could not load configuration files: \(error)"))
                config = Config()
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

        // account for all types provided
        // to the droplet's init method
        var provided = Providable(
            server: server,
            router: router,
            sessions: sessions,
            hash: hash,
            console: console,
            log: log,
            client: client,
            database: database
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
            log.log(item.level, message: item.message)
        }

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

        // initialize the hash from one provided
        // or use a default SHA2 hasher
        let hash = provided.hash ?? SHA2Hasher(variant: .sha256)
        self.hash = hash

        // set the hashing key to the key
        // from the configuration files or nothing.
        hash.key = config["app", "key"].string ?? ""

        // use provided sessions or MemorySessions by default
        let sessions = provided.sessions ?? MemorySessions(hash: hash)
        self.sessions = sessions

        // add the following middleware by default
        // this can be overridden by doing
        //      droplet.globalMiddleware = p[
        // or removing middleware individually
        self.globalMiddleware = [
            FileMiddleware(workDir: workDir),
            SessionMiddleware(sessions: sessions),
            ValidationMiddleware(),
            DateMiddleware(),
            AbortMiddleware()
        ]

        // set the router, server, and client
        // from provided or defaults.
        let router = provided.router ?? BranchRouter()
        self.router = router
        let serverType = provided.server ?? HTTPServer<TCPServerStream, HTTPParser<HTTPRequest>, HTTPSerializer<HTTPResponse>>.self
        self.server = serverType
        let client = provided.client ?? HTTPClient<TCPClientStream>.self
        self.client = client

        // misc arrays and other stored properties
        storage = [:]
        routes = []
        commands = []

        // iterate over preparations to set the
        // supplied database on the models
        if let database = provided.database {
            for preparation in preparations {
                if let model = preparation as? Model.Type {
                    model.database = database
                }
            }
            self.database = database
        } else {
            self.database = nil
        }

        // the prepare command will run all
        // of the supplied preparations on the database.
        let prepare = Prepare(console: console, preparations: preparations, database: database)

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
        if config.environment == .production {
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
