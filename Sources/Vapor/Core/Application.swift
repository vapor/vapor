import libc
import MediaType

public class Application {
    public static let VERSION = "0.8.0"

    /**
        The router driver is responsible
        for returning registered `Route` handlers
        for a given request.
    */
    public var router: RouterDriver = BranchRouter()

    /**
        The server driver is responsible
        for handling connections on the desired port.
        This property is constant since it cannot
        be changed after the server has been booted.
    */
    public var server: Server?

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
    */
    public let port: Int

    /**
        `Middleware` will be applied in the order
        it is set in this array.

        Make sure to append your custom `Middleware`
        if you don't want to overwrite default behavior.
    */
    public var globalMiddleware: [Middleware]

    /**
        Provider classes that have been registered
        with this application
    */
    public var providers: [Provider] = []

    /**
        The work directory of your application is
        the directory in which your Resources, Public, etc
        folders are stored. This is normally `./` if
        you are running Vapor using `.build/xxx/App`
    */
    public var workDir = "./" {
        didSet {
            if self.workDir.characters.last != "/" {
                self.workDir += "/"
            }
        }
    }

    /**
        Resources directory relative to workDir
    */
    public var resourcesDir: String {
        return workDir + "Resources/"
    }

    var routes: [Route] = []

    /**
        Initialize the Application.
    */
    public init(sessionDriver: SessionDriver? = nil, config overrideConfig: Config? = nil) {

        let hash = Hash()
        self.hash = hash
        self.session = sessionDriver ?? MemorySessionDriver(hash: hash)

        let workDir = Process.valueFor(argument: "workDir") ?? "./"
        self.workDir = workDir

        let config = overrideConfig ?? Config(workingDirectory: workDir)
        self.config = config

        self.host = config["app", "host"].string ?? "0.0.0.0"

        // Tanner, would like input here.
        // Alternative is
        // the json is strictly typed, we need a way to make it fuzzy
        // or all cli args will be strings.
        self.port = config["app", "port"].string?.int ?? 80

        self.globalMiddleware = [
            AbortMiddleware(),
            ValidationMiddleware(),
            SessionMiddleware(session: session)
        ]
    }

    public func bootProviders() {
        for provider in self.providers {
            provider.boot(with: self)
        }
    }

    func bootRoutes() {
        routes.forEach(router.register)
    }

    /**
        Boots the chosen server driver and
        optionally runs on the supplied
        ip & port overrides
    */
    public func start() {
        bootProviders()

        bootRoutes()

        if config.environment == .production {
            Log.info("Production environment detected, disabling information logs.")
            Log.enabledLevels = [.error, .fatal]
        }

        do {
            Log.info("Server starting on \(host):\(port)")

            let server: Server
            if let presetServer = self.server {
                server = presetServer
            } else {
                server = try HTTPStreamServer<ServerSocket>(
                    host: host,
                    port: port,
                    responder: self
                )
                self.server = server
            }

            try server.start()
        } catch {
            Log.error("Server start error: \(error)")
        }
    }

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
                    let fileExtension = filePath.split(byString: ".").last,
                    let type = mediaType(forFileExtension: fileExtension)
                {
                    headers["Content-Type"] = Response.Headers.Values(type.description)
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

        request.parseData()

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

            if response.headers["Content-Type"].first == nil {
                Log.warning("Response had no 'Content-Type' header.")
            }
        } catch {
            var error = "Server Error: \(error)"
            if config.environment == .production {
                error = "Something went wrong"
            }

            response = Response(error: error)
        }

        response.headers["Date"] = Response.Headers.Values(Response.date)
        response.headers["Server"] = Response.Headers.Values("Vapor \(Application.VERSION)")

        return response
    }

    func test() {


    }
}
