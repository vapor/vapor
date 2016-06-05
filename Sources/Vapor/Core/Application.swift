import libc
import MediaType
import Foundation
import Socks

public let VERSION = "0.10"

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
    public var globalMiddleware: [Middleware]

    /**
        the commands available to execute on the application
    */
    public private(set) var commands: [String : Command.Type] = [
        Help.id: Help.self,
        Serve.id: Serve.self
    ]

    /**
        Resources directory relative to workDir
    */
    public var resourcesDir: String {
        return workDir + "Resources/"
    }

    var routes: [Route]

    /**
        Initialize the Application.
    */
    public init(
        workDir: String? = nil,
        config: Config? = nil,
        localization: Localization? = nil,
        hash: HashDriver? = nil,
        server: ServerDriver.Type? = nil,
        router: RouterDriver? = nil,
        session: SessionDriver? = nil,
        providers: [Provider] = []
    ) {
        var serverProvided: ServerDriver.Type? = server
        var routerProvided: RouterDriver? = router
        var sessionProvided: SessionDriver? = session
        var hashProvided: HashDriver? = hash

        for provider in providers {
            serverProvided = provider.server ?? serverProvided
            routerProvided = provider.router ?? routerProvided
            sessionProvided = provider.session ?? sessionProvided
            hashProvided = provider.hash ?? hashProvided
        }

        let workDir = workDir
            ?? Process.valueFor(argument: "workDir")
            ?? "./"
        self.workDir = workDir.finish("/")

        let localization = localization ?? Localization(workingDirectory: workDir)
        self.localization = localization

        let config = config ?? Config(workingDirectory: workDir)
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
        self.server = serverProvided ?? StreamServer<
            SynchronousTCPServer,
            HTTPParser,
            HTTPSerializer
        >.self

        routes = []

        restrictLogging(for: config.environment)

        for provider in providers {
            provider.boot(with: self)
        }
    }

    private func restrictLogging(for environment: Environment) {
        guard config.environment == .production else { return }
        Log.info("Production environment detected, disabling information logs.")
        Log.enabledLevels = [.error, .fatal]
    }
}

extension Application {
    /**
        Starts console
    */
    public func start() {
        // defaults to serve which will result in a no return
        //code beyond this call will only execute in event of failure
        executeCommand()
    }

    private func executeCommand() {
        let input = NSProcessInfo.processInfo().arguments
        let (command, arguments) = extract(fromInput: input)
        command.run(on: self, with: arguments)
    }

    internal func extract(fromInput input: [String]) -> (command: Command.Type, arguments: [String]) {
        // options prefixed w/ `--` are accessible through `app.config["app", "argument"]`
        var iterator = input
            .filter { !$0.hasPrefix("--") }
            .makeIterator()
        let _ = iterator.next() // dump directory command
        let commandKey = iterator.next() ?? "serve"
        let arguments = Array(iterator)

        let command = commands[commandKey] ?? Serve.self
        return (command, arguments)
    }
}

extension Application {
    internal func serve() {
        do {
            Log.info("Server starting at \(host):\(port)")
            // noreturn
            let server = try self.server.init(host: host, port: port, responder: self)
            try server.start()
        } catch {
            Log.error("Server start error: \(error)")
        }
    }
}

extension Application {
    func checkFileSystem(for request: Request) -> Request.Handler? {
        // Check in file system
        let filePath = self.workDir + "Public" + (request.uri.path ?? "")

        guard FileManager.fileAtPath(filePath).exists else {
            return nil
        }

        // File exists
        if let fileBody = try? FileManager.readBytesFromFile(filePath) {
            return Request.Handler { _ in
                var headers: Response.Headers = [:]

                if
                    let fileExtension = filePath.components(separatedBy: ".").last,
                    let type = mediaType(forFileExtension: fileExtension)
                {
                    headers["Content-Type"] = type.description
                }

                return Response(status: .ok, headers: headers, body: Data(fileBody))
            }
        } else {
            return Request.Handler { _ in
                Log.warning("Could not open file, returning 404")
                return Response(status: .notFound, text: "Page not found")
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

extension Application: Responder {

    /**
        Returns a response to the given request

        - parameter request: received request

        - throws: error if something fails in finding response

        - returns: response if possible
     */
    public func respond(to request: Request) throws -> Response {
        Log.info("\(request.method) \(request.uri.path ?? "/")")

        var responder: Responder
        var request = request

        request.cacheParsedContent()

        // Check in routes
        if let (parameters, routerHandler) = router.route(request) {
            request.parameters = parameters
            responder = routerHandler
        } else if let fileHander = self.checkFileSystem(for: request) {
            responder = fileHander
        } else {
            // Default not found handler
            responder = Request.Handler { _ in
                return Response(status: .notFound, text: "Page not found")
            }
        }

        // Loop through middlewares in order
        for middleware in self.globalMiddleware {
            responder = middleware.chain(to: responder)
        }

        var response: Response
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

            response = Response(error: error)
        }

        response.headers["Date"] = Response.date
        response.headers["Server"] = "Vapor \(Vapor.VERSION)"

        return response
    }
}

// MARK: Commands

extension Application {
    public func add(_ cmd: Command.Type) {
        if let existing = commands[cmd.id] {
            Log.warning("Overwriting command: \(existing) with \(cmd)")
        }
        commands[cmd.id] = cmd
    }

    public func remove(_ cmd: Command.Type) {
        guard commands[cmd.id] != nil else { return }
        guard let existing = commands[cmd.id] where existing != cmd else {
            Log.info("Command with id \(cmd.id) exists as a different type: \(commands[cmd.id]). Not removing")
            return
        }
        commands[cmd.id] = nil
    }
}
