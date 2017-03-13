// MARK: Server

import Settings

typealias Runner = (Droplet) throws -> Void

struct Up: Error {
    let message: String
    init(_ message: String) {
        self.message = message
    }
}

func up(f: String = #function, l: Int = #line) -> Up {
    return Up("function: \(f) - line: \(l)")
}

extension Settings.Config {
    func changes(comparedTo new: Settings.Config) throws -> (additions: [String], updates: [String], subtractions: [String]) {
        var additions = [String]()
        var updates = [String]()
        var subtractions = [String]()

        let original = try self.explode()
        let new = try new.explode()

        original.forEach { path, value in
            if let includedInNew = new[path] {
                guard includedInNew != value else { return }
                updates.append(path)
            } else {
                subtractions.append(path)
            }
        }

        new.forEach { path, value in
            guard original[path] == nil else { return }
            additions.append(path)
        }

        return (additions, updates, subtractions)
    }

    public func explode() throws -> [String: Settings.Config] {
        guard let object = typeObject else { throw up() }
        var exploded: [String: Config] = [:]
        try object.forEach { key, value in
            guard !key.contains(".") else {
                throw Up("you can't use `.` keys in explosion, maybe I can support later ...")
            }

            if value.isObject {
                try value.explode().forEach { path, value in
                    let path = key + "." + path
                    exploded[path] = value
                }

            } else {
                exploded[key] = value
            }
        }

        return exploded
    }
}

extension Droplet {
    var configOptions: [ConfigOption] { return [] }

    func updateConfig(original: Config, new: Config) throws {

    }

    func update(options: [ConfigOption], original: Config, new: Config) throws {
        let (additions, updates, subtractions) = try original.changes(comparedTo: new)

        // Do subtractions first to prevent unexpected removals later
        try options.filter { subtractions.contains($0.path) } .forEach { lostOption in
            try lostOption.disable(with: self)
        }

        // Second, do updates disable old, enable new
        try updates.forEach { updatedPath in
            guard
                let originalOption = original[updatedPath],
                let newOption = new[updatedPath]
                else { throw Up("these should both exist if changes func works properly") }

            let remove = options.lazy.filter { $0.path == updatedPath && $0.matchesFor(originalOption) } .first
            try remove?.disable(with: self)

            let add = options.lazy.filter { $0.path == updatedPath && $0.matchesFor(newOption) } .first
            try add?.enable(with: self)
        }

        try options.filter { additions.contains($0.path) } .forEach { enabled in
            try enabled.enable(with: self)
        }
    }
}

extension StructuredDataWrapper {
    var isObject: Bool {
        return typeObject != nil
    }
}

final class ConfigOption {
    /// config path
    let path: String
    /// type metadata for debugging
    let type: String
    /// a look into the name
    let name: String
    /// the value found at the path will be passed here to
    /// see if it matches
    let matchesFor: (Config) -> Bool
    /// if enabled, configuration run
    private let enableRunner: Runner
    /// if disabled, configuration run
    private let disableRunner: Runner

    fileprivate var enabled = false

    init(
        path: String,
        type: String,
        name: String,
        matchesFor: @escaping (Config) -> Bool,
        enable: @escaping Runner,
        disable: @escaping Runner
    ) {
        self.path = path
        self.type = type
        self.name = name
        self.matchesFor = matchesFor
        self.enableRunner = enable
        self.disableRunner = disable
    }

    func enable(with drop: Droplet) throws {
        guard !enabled else { return }
        try enableRunner(drop)
        enabled = true
    }

    func disable(with drop: Droplet) throws {
        guard enabled else { return }
        try disableRunner(drop)
        enabled = false
    }
}

//final class ConfigurationOptions {
//    struct Option {
//        // config path
//        let path: String
//        // name match
//        let name: String
//        // type metadata for debugging
//        let type: String
//        // if enabled, configuration run
//        let runner: Runner
//    }
//
//    var options: [Option] = []
//    unowned let drop: Droplet
//
//    init(_ drop: Droplet) {
//        self.drop = drop
//    }
//
//    func add(path: String, name: String, type: String, runner: @escaping Runner) {
//        let option = Option(path: path, name: name, type: type, runner: runner)
//        options.append(option)
////        evaluateNewOption(option)
//    }
//
//    func setup(with drop: Droplet) throws {
//        try options.forEach { configurable in
//            guard let existing = drop.config[configurable.path]?.string else {
//                drop.log.debug("Not using \(configurable.type) - \(configurable.name)")
//                return
//            }
//            guard existing == configurable.name else { return }
//            drop.log.debug("Using \(configurable.type) - \(configurable.name)")
//            try configurable.runner(drop)
//        }
//    }
//
//    func evaluateNewOption(_ option: ConfigOption) throws {
//        guard let value = drop.config[option.path] else {
//            drop.log.debug("Not using \(option.type) - \(option.name). No configuration set.")
//            return
//        }
//        guard option.matchesFor(value) else {
//            drop.log.debug("Not using \(option.type) - \(option.name). Failed to match configuration value \(value).")
//            return
//        }
//
//        drop.log.debug("Using \(option.type) - \(option.name)")
//        try option.enable(with: drop)
//    }
//}

extension Droplet {
//    var configurables: ConfigurationOptions {
//        get {
//            if let existing = storage["vapor:configurables"] as? ConfigurationOptions {
//                return existing
//            }
//
//            let configurable = ConfigurationOptions(self)
//            storage["vapor:configurables"] = configurable
//            return configurable
//        }
//        set {
//            storage["vapor:configurables"] = newValue
//        }
//    }

    public func _addConfigurable(server: ServerProtocol.Type, name: String) {
//        configurables.add(
//            path: "droplet.server",
//            name: name,
//            type: "server",
//            runner: { drop in
//                drop.server = server
//                drop.log.debug("Using server '\(name)'.")
//            }
//        )
    }

    public func addConfigurable(forPath path: String, name: String, type: String, matcher: @escaping (Config) -> Bool, enabler: @escaping (Droplet) throws -> Void, disabler: @escaping (Droplet) throws -> Void) {

    }

    public func addConfigurable(server: ServerProtocol.Type, name: String) {
        if config["droplet", "server"]?.string == name {
            self.server = server
            log.debug("Using server '\(name)'.")
        } else {
            log.debug("Not using server '\(name)'.")
        }
    }
}

// MARK: Client

import Transport

extension Droplet {
    public func addConfigurable(client: ClientProtocol.Type, name: String) {
        if config["droplet", "client"]?.string == name {
            self.client = client
            log.debug("Using client '\(name)'.")

            if let tls = config["clients", "tls"]?.object {
                defaultClientConfig = {
                    return try self.parseTLSConfig(tls, mode: .client)
                }
            }
        } else {
            log.debug("Not using client '\(name)'.")
        }
    }
}



// MARK: Log

extension Droplet {
    public func addConfigurable(log: LogProtocol, name: String) {
        if config["droplet", "log"]?.string == name {
            self.log = log
            self.log.debug("Using log '\(name)'.")
        } else {
            self.log.debug("Not using log '\(name)'.")
        }
    }

    public func addConfigurable<L: LogProtocol & ConfigInitializable>(log: L.Type, name: String) throws {
        if config["droplet", "log"]?.string == name {
            self.log = try log.init(config: config)
            self.log.debug("Using log '\(name)'.")
        } else {
            self.log.debug("Not using log '\(name)'.")
        }
    }
}

// MARK: Hash

extension Droplet {
    public func addConfigurable(hash: HashProtocol, name: String) {
        if config["droplet", "hash"]?.string == name {
            self.hash = hash
            log.debug("Using hash '\(name)'.")
        } else {
            log.debug("Not using hash '\(name)'.")
        }
    }

    public func addConfigurable<H: HashProtocol & ConfigInitializable>(hash: H.Type, name: String) throws {
        if config["droplet", "hash"]?.string == name {
            self.hash = try hash.init(config: config)
            log.debug("Using hash '\(name)'.")
        } else {
            log.debug("Not using hash '\(name)'.")
        }
    }
}

// MARK: Cipher

extension Droplet {
    public func addConfigurable(cipher: CipherProtocol, name: String) {
        if config["droplet", "cipher"]?.string == name {
            self.cipher = cipher
            log.debug("Using cipher '\(name)'.")
        } else {
            log.debug("Not using cipher '\(name)'.")
        }
    }

    public func addConfigurable<C: CipherProtocol & ConfigInitializable>(cipher: C.Type, name: String) throws {
        if config["droplet", "cipher"]?.string == name {
            self.cipher = try cipher.init(config: config)
            log.debug("Using cipher '\(name)'.")
        } else {
            log.debug("Not using cipher '\(name)'.")
        }
    }
}

// MARK: Middleware

import HTTP

extension Droplet {
    public func addConfigurable(middleware: Middleware, name: String) {
        if config["droplet", "middleware", "server"]?.array?.flatMap({ $0.string }).contains(name) == true {
            self.middleware.append(middleware)
            log.debug("Using server middleware '\(name)'.")
        } else {
            log.debug("Not using server middleware '\(name)'.")
        }

        if config["droplet", "middleware", "client"]?.array?.flatMap({ $0.string }).contains(name) == true {
            let cm = self.client.defaultMiddleware
            self.client.defaultMiddleware = cm + [middleware]
            log.debug("Using client middleware '\(name)'.")
        } else {
            log.debug("Not using client middleware '\(name)'.")
        }
    }
}

// MARK: Console

import Console

extension Droplet {
    public func addConfigurable(console: ConsoleProtocol, name: String) {
        if config["droplet", "console"]?.string == name {
            self.console = console
            log.debug("Using console '\(name)'.")
        } else {
            log.debug("Not using console '\(name)'.")
        }
    }

    public func addConfigurable<C: ConsoleProtocol & ConfigInitializable>(console: C.Type, name: String) throws {
        if config["droplet", "console"]?.string == name {
            self.console = try console.init(config: config)
            log.debug("Using console '\(name)'.")
        } else {
            log.debug("Not using console '\(name)'.")
        }
    }
}

// MARK: Cache

import Cache

extension Droplet {
    public func addConfigurable(cache: CacheProtocol, name: String) {
        if config["droplet", "cache"]?.string == name {
            self.cache = cache
            log.debug("Using cache '\(name)'.")
        } else {
            log.debug("Not using cache '\(name)'.")
        }
    }

    public func addConfigurable<C: CacheProtocol & ConfigInitializable>(cache: C.Type, name: String) throws {
        if config["droplet", "cache"]?.string == name {
            self.cache = try cache.init(config: config)
            log.debug("Using cache '\(name)'.")
        } else {
            log.debug("Not using cache '\(name)'.")
        }
    }
}
