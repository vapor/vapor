import libc
import Foundation
import Socks

public let VERSION = "0.11"

public class Application {
    /**
        The router driver is responsible
        for returning registered `Route` handlers
        for a given request.
    */
    public let router: RouterDriver

    /**
        The server that will accept requesting
        connections and return the desired
        response.
    */
    public let server: ServerDriver.Type

    /**
        The session driver is responsible for
        storing and reading values written to the
        users session.
    */
    public let session: SessionDriver

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
        The base host to serve for a given application. Set through Config
     
        Command Line Argument:
            `--config:app.host=127.0.0.1`
         
        Config:
            Set "host" key in app.json file
    */
    public let host: String

    /**
        The port the application should listen to. Set through Config

        Command Line Argument:
            `--config:app.port=8080`

        Config:
            Set "port" key in app.json file
    */
    public let port: Int

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
    public var globalMiddleware: [HTTPMiddleware]

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
    public let client: HTTPClientProtocol


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

    /**
        Initialize the Application.
    */
    public init(
        workDir: String? = nil,
        config: Config? = nil,
        localization: Localization? = nil,
        hash: HashDriver? = nil,
        console: ConsoleDriver? = nil,
        server: ServerDriver.Type? = nil,
        client: HTTPClientProtocol? = nil,
        router: RouterDriver? = nil,
        session: SessionDriver? = nil,
        providers: [Provider] = [],
        arguments: [String]? = nil
    ) {
        var serverProvided: ServerDriver.Type? = server
        var routerProvided: RouterDriver? = router
        var sessionProvided: SessionDriver? = session
        var hashProvided: HashDriver? = hash
        var consoleProvided: ConsoleDriver? = console
        var clientProvided: HTTPClientProtocol? = nil

        for provider in providers {
            // TODO: Warn if multiple providers attempt to add server
            serverProvided = provider.server ?? serverProvided
            routerProvided = provider.router ?? routerProvided
            sessionProvided = provider.session ?? sessionProvided
            hashProvided = provider.hash ?? hashProvided
            consoleProvided = provider.console ?? consoleProvided
            clientProvided = provider.client ?? clientProvided
        }

        let arguments = arguments ?? NSProcessInfo.processInfo().arguments
        self.arguments = arguments

        let workDir = workDir
            ?? arguments.value(for: "workdir")
            ?? arguments.value(for: "workDir")
            ?? "./"
        self.workDir = workDir.finish("/")

        let localization = localization ?? Localization(workingDirectory: workDir)
        self.localization = localization

        let config = config ?? Config(workingDirectory: workDir, arguments: arguments)
        self.config = config

        let host = config["app", "host"].string ?? "0.0.0.0"
        let port = config["app", "port"].int ?? 8080
        self.host = host
        self.port = port

        let key = config["app", "key"].string
        let hash = Hash(key: key, driver: hashProvided)
        self.hash = hash

        let session = sessionProvided ?? MemorySessionDriver(hash: hash)
        self.session = session

        self.globalMiddleware = [
            AbortMiddleware(),
            ValidationMiddleware(),
            SessionMiddleware(session: session)
        ]

        self.router = routerProvided ?? BranchRouter()
        self.server = serverProvided ?? DefaultServer.self
        self.client = clientProvided ?? HTTPClient<TCPClient>()

        routes = []

        commands = []

        let console = Console(driver: consoleProvided ?? Terminal())
        self.console = console

        Log.driver = ConsoleLogger(console: console)

        commands.append(Help.self)
        commands.append(Serve.self)

        restrictLogging(for: config.environment)

        for provider in providers {
            provider.boot(with: self)
        }
    }

    private func restrictLogging(for environment: Environment) {
        guard config.environment == .production else { return }
        console.output("Production mode enabled, disabling informational logs.", style: .info)
        Log.enabledLevels = [.error, .fatal]
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
    public func start() {
        do {
            try execute()
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
                console.output(error)
            }
        } catch  {
            console.output("Error: \(error)", style: .error)
        }
        exit(1)
    }

    func execute() throws {
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

                try command.run()
                return
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
    internal func serve() {
        do {
            console.output("Server starting at \(host):\(port)", style: .info)
            // noreturn
            let server = try self.server.init(host: host, port: port, responder: self)
            try server.start()
        } catch ServerError.bindFailed {
            console.output("Could not bind to port \(port), it may be in use or require sudo.", style: .error)
        } catch {
            Log.error("Server start error: \(error)")
        }
    }
}

extension Application {
    func checkFileSystem(for request: HTTPRequest) -> HTTPRequest.Handler? {
        // Check in file system
        let filePath = self.workDir + "Public" + (request.uri.path ?? "")

        guard FileManager.fileAtPath(filePath).exists else {
            return nil
        }

        // File exists
        if let fileBody = try? FileManager.readBytesFromFile(filePath) {
            return HTTPRequest.Handler { _ in
                var headers: Headers = [:]

                if
                    let fileExtension = filePath.components(separatedBy: ".").last,
                    let type = mediaTypes[fileExtension]
                {
                    headers["Content-Type"] = type.description
                }

                return HTTPResponse(status: .ok, headers: headers, body: .data(fileBody))
            }
        } else {
            return HTTPRequest.Handler { _ in
                Log.warning("Could not open file, returning 404")
                let bod = "Page not found".utf8.array
                return HTTPResponse(status: .notFound, body: .data(bod))
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

extension Application: HTTPResponder {

    /**
        Returns a response to the given request

        - parameter request: received request

        - throws: error if something fails in finding response

        - returns: response if possible
     */
    public func respond(to request: HTTPRequest) throws -> HTTPResponse {
        Log.info("\(request.method) \(request.uri.path ?? "/")")

        var responder: HTTPResponder
        let request = request

        /*
            The HEAD method is identical to GET.
            
            https://tools.ietf.org/html/rfc2616#section-9.4
        */
        let originalMethod = request.method
        if case .head = request.method {
            request.method = .get
        }


        // Check in routes
        if let handler = router.route(request) {
            responder = handler
        } else if let fileHander = self.checkFileSystem(for: request) {
            responder = fileHander
        } else {
            // Default not found handler
            responder = HTTPRequest.Handler { _ in
                let normal: [Method] = [.get, .post, .put, .patch, .delete]

                if normal.contains(request.method) {
                    let data = "Page not found".utf8.array
                    return HTTPResponse(status: .notFound, body: .data(data))
                } else if case .options = request.method {
                    return HTTPResponse(status: .ok, headers: [
                        "Allow": "OPTIONS"
                        ])
                } else {
                    return HTTPResponse(status: .notImplemented)
                }
            }
        }

        // Loop through middlewares in order
        responder = self.globalMiddleware.chain(to: responder)

        var response: HTTPResponse
        do {
            response = try responder.respond(to: request)

            if response.headers["Content-Type"] == nil {
                Log.warning("Response had no 'Content-Type' header.")
            }
        } catch {
            var error = "Server Error: \(error)"
            if config.environment == .production {
                error = "Something went wrong"
            }
            response = HTTPResponse(error: error)
        }

        response.headers["Date"] = RFC1123.now()
        response.headers["Server"] = "Vapor \(Vapor.VERSION)"

        /**
            The server MUST NOT return a message-body in the response for HEAD.

            https://tools.ietf.org/html/rfc2616#section-9.4
        */
        if case .head = originalMethod {
            // TODO: What if body is set to chunked¿?
            response.body = .data([])
        }

        return response
    }
}
