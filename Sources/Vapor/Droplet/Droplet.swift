import HTTP
import Console
import Cache
import Sessions
import Crypto
import Transport
import Sockets
import Service
import Configs
import Routing

public final class Droplet: Container {
    /// Config file name
    public static let configKey = "droplet"

    /// Provides access to config settings.
    public let config: Configs.Config
    
    /// Services available to this service container.
    public let services: Services

    /// The responder includes chained middleware
    internal var responder: Responder!

    /// Extendable
    public var extend: [String: Any]

    /// Creates a Droplet.
    public init(
        _ config: Configs.Config? = nil,
        _ services: Services? = nil,
        _ router: Router? = nil
    ) throws {
        var config = config ?? Config.default()
        // port override
        if let port = config.arguments.value(for: "port") {
            try config.set("server", "port", to: port)
        }
        self.config = config
        let services = services ?? Services.default()
        
        self.services = services
        extend = [:]

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
        try services.providers.forEach { provider in
            try provider.boot(self)
        }
    }
}
