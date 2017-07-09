import HTTP
import Console
import Cache
import Sessions
import Crypto
import Transport
import Sockets

public final class Droplet {
    /// Provides access to config settings.
    public let config: Config
    
    /// Services available to this service container.
    public let services: Services

    /// The responder includes chained middleware
    internal var responder: Responder!
    
    /// Storage to add/manage dependencies, identified by a string
    public var storage: [String: Any]
    
    /// External service providers that have registered
    /// services and modified the Droplet.
    public let providers: [Provider]

    /// Creates a Droplet.
    public init(
        _ config: Config? = nil,
        _ services: Services? = nil,
        _ router: Router? = nil
    ) throws {
        var config = config ?? Config.default()
        // port override
        if let port = config.arguments.value(for: "port")?.int {
            try config.set("server.port", port)
        }
        self.config = config
        var services = services ?? Services.default()
        
        let providers = try services.providerTypes.map { providerType in
            return try providerType.init(config: config)
        } + services.providers
        
        try providers.forEach { provider in
            try provider.register(&services)
        }
        
        self.services = services
        self.providers = providers
        self.storage = [:]

        let environment = config.environment
        
        let log = try self.log()
        let router = try self.router()
        
        let chain = try middleware().chain(to: router)
        let responder = Request.Handler { request in
            log.info("\(request.method) \(request.uri.path)")

            let isHead = request.method == .head
            if isHead {
                /// The HEAD method is identical to GET.
                ///
                /// https://tools.ietf.org/html/rfc2616#section-9.4
                request.method = .get
            }

            let response: Response
            do {
                response = try chain.respond(to: request)
            } catch {
                log.error("Uncaught error: \(type(of: error))")
                log.swiftError(error)
                log.info("Use `ErrorMiddleware` or catch \(type(of: error)) to provide a better error response.")
                response = Response(status: .internalServerError)
            }

            if isHead {
                /// The server MUST NOT return a message-body in the response for HEAD.
                ///
                /// https://tools.ietf.org/html/rfc2616#section-9.4
                response.body = .data([])
            }

            return response
        }

        self.responder = responder

        // post init
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
        
        // disable cache by default during development
        try view().shouldCache = environment == .production

        // boot providers
        try providers.forEach { provider in
            try provider.boot(self)
        }
    }
}
