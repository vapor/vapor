import libc
import Foundation
import Socks
import Engine
import Console

public let VERSION = "0.14.0"

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
     Provides access to config settings.
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
        TODO: Expose to end users to customize driver
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

    var routes: [Route]

    public let preparations: [Preparation.Type]

    public let database: Database?

    public let log: Log

    /**
        Initialize the Droplet.
    */
    public init(
        workDir: String? = nil,
        config: Config? = nil,
        localization: Localization? = nil,
        hash: Hash? = nil,
        console: ConsoleProtocol? = nil,
        server: Server.Type? = nil,
        client: Client.Type? = nil,
        router: Router? = nil,
        session: Sessions? = nil,
        database: DatabaseDriver? = nil,
        preparations: [Preparation.Type] = [],
        providers: [Provider] = [],
        arguments: [String]? = nil
    ) {
        var serverProvided: Server.Type? = server
        var routerProvided: Router? = router
        var sessionsProvided: Sessions? = session
        var hashProvided: Hash? = hash
        var consoleProvided: ConsoleProtocol? = console
        var clientProvided: Client.Type? = client
        var databaseProvided: DatabaseDriver? = database

        for provider in providers {
            // TODO: Warn if multiple providers attempt to add server
            serverProvided = provider.server ?? serverProvided
            routerProvided = provider.router ?? routerProvided
            sessionsProvided = provider.sessions ?? sessionsProvided
            hashProvided = provider.hash ?? hashProvided
            consoleProvided = provider.console ?? consoleProvided
            clientProvided = provider.client ?? clientProvided
            databaseProvided = provider.database ?? databaseProvided
        }

        let arguments = arguments ?? ProcessInfo.arguments()
        self.arguments = arguments

        let console = consoleProvided ?? Terminal(arguments: arguments)
        self.console = console

        let log = ConsoleLogger(console: console)
        self.log = log

        func fileWorkDirectory() -> String? {
            let parts = #file.components(separatedBy: "/Packages/Vapor-")
            guard parts.count == 2 else {
                return nil
            }

            return parts.first
        }

        let workDir = workDir
            ?? arguments.value(for: "workdir")
            ?? arguments.value(for: "workDir")
            ?? fileWorkDirectory()
            ?? "./"
        self.workDir = workDir.finished(with: "/")

        let localizationProvided = localization
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

        let configProvided = config
        let config: Config
        if let provided = configProvided {
            config = provided
        } else {
            do {
                config = try Config(workingDirectory: workDir, arguments: arguments)
            } catch {
                log.error("Could not load configuration files: \(error)")
                config = Config()
            }
        }
        self.config = config
        
        self.storage = [:]

        let key = config["app", "key"].string
        let hash = hashProvided ?? SHA2Hasher(variant: .sha256)
        hash.key = key ?? ""
        self.hash = hash

        let sessions = sessionsProvided ?? MemorySessions(hash: hash)
        self.sessions = sessions

        self.globalMiddleware = [
            AbortMiddleware(),
            ValidationMiddleware(),
            SessionMiddleware(sessions: sessions),
            DateMiddleware()
        ]

        let router = routerProvided ?? BranchRouter()
        self.router = router

        let serverType = serverProvided ?? HTTPServer<TCPServerStream, HTTPParser<HTTPRequest>, HTTPSerializer<HTTPResponse>>.self
        self.server = serverType

        let client = clientProvided ?? HTTPClient<TCPClientStream>.self
        self.client = client

        routes = []
        commands = []

        self.preparations = preparations

        if let driver = databaseProvided {
            let database = Database(driver)
            for preparation in preparations {
                if let model = preparation as? Model.Type {
                    model.database = database
                }
            }
            self.database = database
        } else {
            self.database = nil
        }

        let prepare = Prepare(console: console, preparations: preparations, database: self.database)

        let serve = Serve(console: console, prepare: prepare) {
            try self.serve()
        }

        let version = VersionCommand(console: console)

        commands.append(serve)
        commands.append(prepare)
        commands.append(version)

        restrictLogging(for: config.environment)

        for provider in providers {
            provider.boot(with: self)
        }
    }

    private func restrictLogging(for environment: Environment) {
        guard config.environment == .production else { return }
        console.output("Production mode enabled, disabling informational logs.", style: .info)
        log.enabled = [.error, .fatal]
    }

    func serverErrors(error: ServerError) {
        log.error("Server error: \(error)")
    }
}

extension Droplet {
    enum ExecutionError: Swift.Error {
        case insufficientArguments, noCommandFound
    }

    /**
        Runs the Droplet's commands, defaulting to serve.
    */
    public func serve(_ closure: Serve.ServeFunction? = nil) -> Never  {
        do {
            try runCommands()
        } catch CommandError.general(let error) {
            console.output(error, style: .error)
            exit(1)
        } catch ConsoleError.help {
            //
        } catch ConsoleError.cancelled {
            exit(2)
        } catch ConsoleError.commandNotFound(let command) {
            console.error("Error: ", newLine: false)
            console.print("Command \"\(command)\" not found.")
        } catch {
            console.error("Error: ", newLine: false)
            console.print("\(error)")
            exit(1)
        }
        exit(0)
    }

    public func runCommands() throws {
        var iterator = arguments.makeIterator()

        guard let executable = iterator.next() else {
            throw CommandError.general("No executable.")
        }

        var args = Array(iterator)

        if !args.flag("help") && args.values.count == 0 {
            console.warning("No command supplied, defaulting to serve...")
            args.insert("serve", at: 0)
        }

        try console.run(
            executable: executable,
            commands: commands.map { $0 as Runnable },
            arguments: args,
            help: [
                "This command line interface is used to serve your droplet, prepare the database, and more.",
                "Custom commands can be added by appending them to the Droplet's commands array.",
                "Use --help on individual commands to learn more."
            ]
        )
    }
}

extension Sequence where Iterator.Element == String {
    func value(for string: String) -> String? {
        for item in self {
            let search = "--\(string)="
            if item.hasPrefix(search) {
                return item.replacingOccurrences(of: search, with: "")
            }
        }

        return nil
    }
}

extension Droplet {
    // TODO: Can this be middleware?
    func checkFileSystem(for request: HTTPRequest) -> HTTPRequest.Handler? {
        // Check in file system
        let filePath = self.workDir + "Public" + request.uri.path

        guard FileManager.fileAtPath(filePath).exists else {
            return nil
        }

        // File exists
        if let fileBody = try? FileManager.readBytesFromFile(filePath) {
            return HTTPRequest.Handler { _ in
                var headers: [HeaderKey: String] = [:]

                if
                    let fileExtension = filePath.components(separatedBy: ".").last,
                    let type = mediaTypes[fileExtension]
                {
                    headers["Content-Type"] = type
                }

                return HTTPResponse(status: .ok, headers: headers, body: .data(fileBody))
            }
        } else {
            return HTTPRequest.Handler { _ in
                self.log.warning("Could not open file, returning 404")
                let bod = "Page not found".utf8.array
                return HTTPResponse(status: .notFound, body: .data(bod))
            }
        }
    }
}

extension Droplet {
    public func add(_ middleware: Middleware...) {
        middleware.forEach { globalMiddleware.append($0) }
    }
    public func add(_ middleware: [Middleware]) {
        middleware.forEach { globalMiddleware.append($0) }
    }
}

func +=(lhs: inout [String], rhs: String) {
    lhs.append(rhs)
}
