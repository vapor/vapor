import libc
import Foundation
import Socks
import Strand

public let VERSION = "0.12"

public typealias Droplet = Application

public class Application {
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
     Provides access to config settings.
     */
    public let localization: Localization

    /**
        Provides access to the underlying
        `HashDriver`.
    */
    public let hash: Hash

    /**
        The work directory of your application is
        the directory in which your Resources, Public, etc
        folders are stored. This is normally `./` if
        you are running Vapor using `.build/xxx/App`
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
        the application.
    */
    public var commands: [Command.Type]

    /**
         Send output and receive input from the console
         using the underlying `ConsoleDriver`.
    */
    public let console: Console

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
        The arguments passed to the application.
    */
    public let arguments: [String]

    var routes: [Route]

    public let preparations: [Preparation.Type]

    public let database: Database?

    public let log: Log

    /**
        Initialize the Application.
    */
    public init(
        workDir: String? = nil,
        config: Config? = nil,
        localization: Localization? = nil,
        hash: Hash? = nil,
        console: Console? = nil,
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
        var consoleProvided: Console? = console
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

        let arguments = arguments ?? ProcessInfo.processInfo().arguments
        self.arguments = arguments

        let console = consoleProvided ?? Terminal()
        self.console = console

        let log = ConsoleLogger(console: console)
        self.log = log

        let workDir = workDir
            ?? arguments.value(for: "workdir")
            ?? arguments.value(for: "workDir")
            ?? "./"
        self.workDir = workDir.finish("/")

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

        let serverType = serverProvided ?? HTTPServer<TCPServerStream, HTTPParser<Request>, HTTPSerializer<Response>>.self
        self.server = serverType

        let client = clientProvided ?? HTTPClient<TCPClientStream>.self
        self.client = client

        routes = []
        commands = []

        self.preparations = preparations

        if let driver = databaseProvided {
            let database = Database(driver: driver)
            for preparation in preparations {
                if let model = preparation as? Model.Type {
                    model.database = database
                }
            }
            self.database = database
        } else {
            self.database = nil
        }

        commands.append(Help.self)
        commands.append(Serve.self)
        commands.append(Prepare.self)

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

extension Application {
    enum ExecutionError: ErrorProtocol {
        case insufficientArguments, noCommandFound
    }

    /**
        Starts console
    */
    @noreturn
    public func serve(_ closure: Serve.ServeFunction? = nil) {
        do {
            let command = try loadCommand()

            if let serveCommand = command as? Serve {
                serveCommand.serve = closure
            }

            try command.run()
            exit(0)
        } catch let error as ExecutionError {
            switch error {
            case .insufficientArguments:
                console.output("Insufficient arguments.", style: .error)
            case .noCommandFound:
                console.output("Command not recognized. Run 'help' for a list of available commands.", style: .error)
            }
        } catch let error as CommandError {
            switch error {
            case .insufficientArguments:
                console.output("Insufficient arguments.", style: .error)
            case .invalidArgument(let name):
                console.output("Invalid argument name '\(name)'.", style: .error)
            case .custom(let error):
                console.output(error, style: .error)
            }
        } catch  {
            console.output("Error: \(error)", style: .error)
        }
        exit(1)
    }

    func loadCommand() throws -> Command {
        // options prefixed w/ `--` are accessible through `app.config["app", "argument"]`
        var iterator = self.arguments.filter { item in
            return !item.hasPrefix("--")
        }.makeIterator()

        _ = iterator.next() // pop location arg

        let commandId: String
        if let next = iterator.next() {
            commandId = next
        } else {
            commandId = "serve"
            console.output("No command supplied, defaulting to 'serve'.", style: .warning)
        }

        let arguments = Array(iterator)

        for commandType in commands {
            if commandType.id == commandId {
                let command = commandType.init(app: self)
                
                let requiredArguments = command.dynamicType.signature.filter { signature in
                    return signature is Argument
                }

                if arguments.count < requiredArguments.count {
                    let signature = command.dynamicType.signature()
                    console.output(signature)
                    throw ExecutionError.insufficientArguments
                }

                return command
            }
        }

        throw ExecutionError.noCommandFound
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

extension Application {
    // TODO: Can this be middleware?
    func checkFileSystem(for request: Request) -> Request.Handler? {
        // Check in file system
        let filePath = self.workDir + "Public" + (request.uri.path ?? "")

        guard FileManager.fileAtPath(filePath).exists else {
            return nil
        }

        // File exists
        if let fileBody = try? FileManager.readBytesFromFile(filePath) {
            return Request.Handler { _ in
                var headers: Headers = [:]

                if
                    let fileExtension = filePath.components(separatedBy: ".").last,
                    let type = mediaTypes[fileExtension]
                {
                    headers["Content-Type"] = type.description
                }

                return Response(status: .ok, headers: headers, body: .data(fileBody))
            }
        } else {
            return Request.Handler { _ in
                self.log.warning("Could not open file, returning 404")
                let bod = "Page not found".utf8.array
                return Response(status: .notFound, body: .data(bod))
            }
        }
    }
}

extension Application {
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
