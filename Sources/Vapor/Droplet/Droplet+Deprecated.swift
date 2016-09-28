import HTTP
import Fluent
import Cache
import Console
import Sessions
import HMAC
import Cipher
import Transport

extension Droplet {
    @available(*, deprecated: 1.0, message: "This init method will be removed in a future update. Use `add` and `addConfigurable` methods instead.")
    public convenience init(
        // non-providable
        arguments: [String]? = nil,
        workDir workDirProvided: String? = nil,
        environment environmentProvided: Environment? = nil,
        config configProvided: Settings.Config? = nil,
        localization localizationProvided: Localization? = nil,

        // providable
        server: ServerProtocol.Type? = nil,
        hash: HashProtocol? = nil,
        cipher: CipherProtocol? = nil,
        console: ConsoleProtocol? = nil,
        log: Log? = nil,
        view: ViewRenderer? = nil,
        client: ClientProtocol.Type? = nil,
        database: Database? = nil,
        cache: CacheProtocol? = nil,

        // middleware
        availableMiddleware: [String: Middleware]? = nil,
        serverMiddleware: [String]? = nil,
        clientMiddleware: [String]? = nil,
        staticServerMiddleware: [Middleware]? = nil,
        staticClientMiddleware: [Middleware]? = nil,

        // database preparations
        preparations: [Preparation.Type] = [],

        // providers
        providers providerTypes: [Provider.Type] = [],
        initializedProviders: [Provider] = []
    ) {
        self.init(
            arguments: arguments,
            workDir: workDirProvided,
            environment: environmentProvided,
            config: configProvided,
            localization: localizationProvided
        )

        // create an array of all providers
        for provider in initializedProviders {
            add(provider)
        }

        for providerType in providerTypes {
            do {
                try add(providerType)
            } catch {
                self.log.error("Could not initialize provider \(providerType): \(error)")
            }
        }

        if let server = server {
            self.server = server
        }

        if let hash = hash {
            self.hash = hash
        }

        if let cipher = cipher {
            self.cipher = cipher
        }

        if let console = console {
            self.console = console
        }

        if let log = log {
            self.log = log
        }

        if let view = view {
            self.view = view
        }

        if let client = client {
            self.client = client
        }

        if let database = database {
            self.database = database
        }

        if let cache = cache {
            self.cache = cache
        }

        self.client.defaultMiddleware = []

        var middleware: [String: Middleware] = [
            "file": FileMiddleware(workDir: workDir),
            "validation": ValidationMiddleware(),
            "date": DateMiddleware(),
            "type-safe": TypeSafeErrorMiddleware(),
            "abort": AbortMiddleware(),
            "sessions": SessionsMiddleware(sessions: MemorySessions())
        ]

        for (name, m) in (availableMiddleware ?? [:]) {
            middleware[name] = m
        }


        if let clients = clientMiddleware {
            for (name, middleware) in middleware {
                if clients.contains(name) {
                    let cm = self.client.defaultMiddleware
                    self.client.defaultMiddleware = cm + [middleware]
                }
            }
        } else if let clients = config["middleware", "client"]?.array?.flatMap({ $0.string }) {
            for (name, middleware) in middleware {
                if clients.contains(name) {
                    let cm = self.client.defaultMiddleware
                    self.client.defaultMiddleware = cm + [middleware]
                }
            }
        }

        if let servers = serverMiddleware {
            self.middleware = []
            for (name, middleware) in middleware {
                if servers.contains(name) {
                    self.middleware.append(middleware)
                }
            }
        } else if let servers = config["middleware", "server"]?.array?.flatMap({ $0.string }) {
            for (name, middleware) in middleware {
                if servers.contains(name) {
                    self.middleware.append(middleware)
                }
            }
        } else {
            self.middleware += Array(middleware.values)
        }

        if let middleware = staticServerMiddleware {
            self.middleware += middleware
        }

        if let middleware = staticClientMiddleware {
            self.client.defaultMiddleware += middleware
        }

        self.preparations += preparations
    }

    @available(*, deprecated: 1.0, message: "Please use the `middleware` property instead.")
    public var enabledMiddleware: [Middleware] {
        return middleware
    }


    @available(*, deprecated: 1.0, message: "Please use the `middleware` property instead.")
    public var availableMiddleware: [String: Middleware] {
        return [:]
    }
}
