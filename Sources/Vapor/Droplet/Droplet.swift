import HTTP
import Console
import Cache
import Session
import Crypto
import Transport
import Sockets
import Service
import Routing


struct WorkingDirectory {
    let workDir = ""
    let publicDir = ""
    let resourcesDir = ""
    let viewsDir = ""
}

public struct Config: Disambiguator {
    var chosenSingle: [String: String]
    var chosenMultiple: [String: [String]]

    public init() {
        self.chosenSingle = [:]
        self.chosenMultiple = [:]
    }

    public func disambiguateSingle<Type>(available: [ServiceFactory], type: Type.Type, for container: Container) throws -> ServiceFactory {
        guard let chosen = chosenSingle["\(Type.self)"] else {
            throw "please choose for \(Type.self)"
        }

        let filtered = available.filter { "\($0.serviceType)" == chosen }
        guard filtered.count == 1 else {
            throw "too many showed up for chosen! \(Type.self)"
        }

        return filtered[0]
    }

    public func disambiguateMultiple<Type>(available: [ServiceFactory], type: Type.Type, for container: Container) throws -> [ServiceFactory] {
        guard let chosen = chosenMultiple["\(Type.self)"] else {
            throw "please choose for \(Type.self)"
        }

        let filtered: [ServiceFactory] = try chosen.map { chosen in
            for service in available {
                if "\(service.serviceType)" == chosen {
                    return service
                }
            }
            throw "could not find service named \(chosen) for \(Type.self)!"
        }

        return filtered
    }

    public mutating func prefer<T, P>(_ type: T.Type, for protocol: P.Type) {
        chosenSingle["\(P.self)"] = "\(T.self)"
    }

    public mutating func prefer<T, P>(_ types: T.Type..., for protocol: [P].Type) {
        chosenMultiple["\(P.self)"] = types.map { "\($0)" }
    }

    public static func `default`() -> Config {
        return Config()
    }
}

public final class Droplet: Container {
    /// Config file name
    public static let configKey = "droplet"

    /// Provides access to config settings.
    public let config: Config

    public var disambiguator: Disambiguator {
        return config
    }

    public let environment: Service.Environment
    
    /// Services available to this service container.
    public let services: Services

    /// The responder includes chained middleware
    internal var responder: Responder!

    /// Extendable
    public var extend: [String: Any]

    /// Creates a Droplet.
    public init(
        config: Config? = nil,
        environment: Service.Environment = .development,
        services: Services? = nil,
        router: Router? = nil,
        arguments: [String] = CommandLine.arguments
    ) throws {
        self.config = Config.default()

        // port override
//        if let port = config.arguments.value(for: "port") {
//            try config.set("server", "port", to: port)
//        }
//        self.config = config
        var services = services ?? Services.default()
        services.register(WorkingDirectory(), name: "workdir")

        
        self.services = services
        extend = [:]

        // let environment = config.environment
        self.environment = environment
        
        let log = try self.log()
        let router = try self.router()
        
        let chain = try middleware().chain(to: router)
        let responder = Request.Handler { request in
            try log.info("\(request.method) \(request.uri.path)")

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
                try log.error("Uncaught error: \(type(of: error))")
                try log.swiftError(error)
                try log.info("Use `ErrorMiddleware` or catch \(type(of: error)) to provide a better error response.")
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
            try log.info("Production mode enabled, disabling informational logs.")
            log.enabled = [.error, .fatal]
        case .development:
            log.enabled = [.info, .warning, .error, .fatal]
        default:
            log.enabled = LogLevel.all
        }
        
        // disable cache by default during development
        // FIXME: cache needs to be properly disabled during prod
        // try view().shouldCache = environment == .production

        // boot providers
        try services.providers.forEach { provider in
            try provider.boot(self)
        }
    }
}
