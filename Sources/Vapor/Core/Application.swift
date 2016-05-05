import libc

public class Application {
    public static let VERSION = "0.5.3"

    /**
        The router driver is responsible
        for returning registered `Route` handlers
        for a given request.
    */
    public lazy var router: RouterDriver = BranchRouter()

    /**
        The server driver is responsible
        for handling connections on the desired port.
        This property is constant since it cannot
        be changed after the server has been booted.
    */
    public lazy var server: Server = HTTPStreamServer<ServerSocket>()

    /**
        The session driver is responsible for
        storing and reading values written to the
        users session.
    */
    public let session: SessionDriver

    /**
        Provides access to config settings.
    */
    public lazy var config: Config = Config(application: self)

    /**
        Provides access to the underlying
        `HashDriver`.
    */
    public let hash: Hash

    /**
        `Middleware` will be applied in the order
        it is set in this array.

        Make sure to append your custom `Middleware`
        if you don't want to overwrite default behavior.
    */
    public var middleware: [Middleware]

    /**
        Provider classes that have been registered
        with this application
    */
    public var providers: [Provider]

    /**
        Internal value populated the first time
        self.environment is computed
    */
    private var detectedEnvironment: Environment?

    /**
        Current environment of the application
    */
    public var environment: Environment {
        if let environment = self.detectedEnvironment {
            return environment
        }

        let environment = bootEnvironment()
        self.detectedEnvironment = environment
        return environment
    }

    /**
        Optional handler to be called when detecting the
        current environment.
    */
    public var detectEnvironmentHandler: ((String) -> Environment)?

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

    var scopedHost: String?
    var scopedMiddleware: [Middleware] = []
    var scopedPrefix: String?

    var port: Int = 80
    var ip: String = "0.0.0.0"

    var routes: [Route] = []

    /**
        Initialize the Application.
    */
    public init(sessionDriver: SessionDriver? = nil) {
        self.middleware = [
            AbortMiddleware(),
            ValidationMiddleware()
        ]

        self.providers = []

        let hash = Hash()
        
        self.session = sessionDriver ?? MemorySessionDriver(hash: hash)
        self.hash = hash

        self.middleware.append(
            SessionMiddleware(session: session)
        )
    }

    public func bootProviders() {
        for provider in self.providers {
            provider.boot(with: self)
        }
    }

    func bootEnvironment() -> Environment {
        var environment: String

        if let value = Process.valueFor(argument: "env") {
            Log.info("Environment override: \(value)")
            environment = value
        } else {
            // TODO: This should default to "production" in release builds
            environment = "development"
        }

        if let handler = self.detectEnvironmentHandler {
            return handler(environment)
        } else {
            return Environment(id: environment)
        }
    }

    /**
        If multiple environments are passed, return
        value will be true if at least one of the passed
        in environment values matches the app environment
        and false if none of them match.

        If a single environment is passed, the return
        value will be true if the the passed in environment
        matches the app environment.
    */
    public func inEnvironment(_ environments: Environment...) -> Bool {
        return environments.contains(self.environment)
    }

    func bootRoutes() {
        routes.forEach(router.register)
    }

    func bootArguments() {
        //grab process args
        if let workDir = Process.valueFor(argument: "workDir") {
            Log.info("Work dir override: \(workDir)")
            self.workDir = workDir
        }

        if let ip = Process.valueFor(argument: "ip") {
            Log.info("IP override: \(ip)")
            self.ip = ip
        }

        if let port = Process.valueFor(argument: "port")?.int {
            Log.info("Port override: \(port)")
            self.port = port
        }
    }

    /**
        Boots the chosen server driver and
        optionally runs on the supplied
        ip & port overrides
    */
    public func start(ip: String? = nil, port: Int? = nil) {
        self.ip = ip ?? self.ip
        self.port = port ?? self.port

        bootArguments()
        bootProviders()

        bootRoutes()

        if environment == .Production {
            Log.info("Production mode detected, disabling information logs.")
            Log.enabledLevels = [.Error, .Fatal]
        }

        do {
            Log.info("Server starting on \(self.ip):\(self.port)")
            try server.serve(self, on: self.ip, at: self.port)
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
                return Response(status: .ok, headers: [:], body: Data(fileBody))
            }
        } else {
            return Request.Handler { _ in
                Log.warning("Could not open file, returning 404")
                return Response(status: .notFound, text: "Page not found")
            }
        }
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
        for middleware in self.middleware {
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
            if environment == .Production {
                error = "Something went wrong"
            }

            response = Response(error: error)
        }

        response.headers["Date"] = Response.Headers.Values(Response.date)
        response.headers["Server"] = Response.Headers.Values("Vapor \(Application.VERSION)")

        return response
    }

}
