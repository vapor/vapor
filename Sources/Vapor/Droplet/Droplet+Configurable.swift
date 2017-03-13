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
    var configOptions: [ConfigOption] {
        get {
            return storage["configOptions"] as? [ConfigOption]
                ?? []
        }
        set {
            storage["configOptions"] = newValue
        }
    }

    func updateConfiguration(original: Config, new: Config) throws {
        let options = configOptions
        let (additions, updates, subtractions) = try original.changes(comparedTo: new)

        // Do subtractions first to prevent unexpected removals later
        try options.filter { subtractions.contains($0.path) } .forEach { lostOption in
            try lostOption.disable(with: self)
        }

        // Second, do updates disable old, enable new
        try updates.forEach { updatedPath in
            let remove = options.lazy.filter { updatedPath.hasPrefix($0.path) } .first
            try remove?.disable(with: self)

            let add = options.lazy.filter { updatedPath.hasPrefix($0.path) } .first
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

//public protocol Configurable {
//    var path: String { get }
//    var type: String { get }
//    var name: String { get }
//    func shouldEnable(forValueAtPath value: Config) -> Bool
//    func enable(for drop: Droplet)
//    func disable(for drop: Droplet)
//}
//
//extension Configurable {
//    public func shouldEnable(forValueAtPath value: Config) -> Bool {
//        return value.string == name
//    }
//}
//
//extension Server: Configurable {
//    public var path: String { return "droplet.server" }
//    public var type: String { return "server" }
//    public var name: String { return "engine" }
//
//    public func enable(for drop: Droplet) {
//        drop.server = type(of: self)
//    }
//
//    public func disable(for drop: Droplet) {}
//}

final class ConfigOption {
    /// config path
    let path: String
    /// type metadata for debugging
    let type: String
    /// a look into the name
    let name: String

    fileprivate var shouldEnable: (Config) -> Bool

    /// if enabled, configuration run
    private let enableRunner: Runner
    /// if disabled, configuration run
    private let disableRunner: Runner

    fileprivate var enabled = false

    init(
        path: String,
        type: String,
        name: String,
        shouldEnable: @escaping (Config) -> Bool,
        enable: @escaping Runner,
        disable: @escaping Runner
    ) {
        self.path = path
        self.type = type
        self.name = name
        self.enableRunner = enable
        self.disableRunner = disable
        self.shouldEnable = { value in
            return value.string == name
        }
    }

    func enable(with drop: Droplet) throws {
        guard !enabled else { return }
        guard let value = drop.config[path] else { return }
        guard shouldEnable(value) else { return }
        drop.log.debug("Enabling \(type) '\(name)'.")
        try enableRunner(drop)
        enabled = true
    }

    func disable(with drop: Droplet) throws {
        guard enabled else { return }
        drop.log.debug("Disabling \(type) '\(name)'.")
        try disableRunner(drop)
        enabled = false
    }
}

//final class Configurable {
//    let runner: (Droplet) throws -> Void
//
//    init(_ runner: @escaping (Droplet) throws -> Void) {
//        self.runner = runner
//    }
//}

typealias Configurable = (Droplet) throws -> Void

extension Droplet {
    // [relevantPath: Runner]
    /*
        when adding new configurable, if path already in config
        On path updates, we trigger the runner again,
        could pass 'updated', 'added', 'removed' possibly
     
        on addConfigurable, if path exists, trigger runner,
        on configuration updates, trigger appropriate runners
    */
    private var configurables: [String: Configurable] {
        get {
            return storage["_configurables"] as? [String: Configurable]
                ?? [:]
        }
        set {
            storage["_configurables"] = newValue
        }
    }

    func _addConfigurable(path: String, configurable: @escaping (Droplet) -> Void) {
        // If the path already exists in config, configure now
        if let _ = config[path] {
            configurable(self)
        }

        configurables[path] = configurable
    }

    func _addConfigurable(path: String, configurable: @escaping Configurable) throws {
        // If the path already exists in config, configure now
        if let _ = config[path] {
            try configurable(self)
        }

        configurables[path] = configurable
    }

//    var configurables: [(Droplet) throws -> Void] {
//        get {
//            return storage["configurables"] as? [(Droplet) throws -> Void]
//                ?? []
//        }
//        set {
//            storage["configurables"] = newValue
//        }
//    }
}



extension Droplet {

    public func addConfigurable(server: ServerProtocol.Type, name: String) {
        _addConfigurable(path: "droplet.server") { drop in
            if drop.config["droplet", "server"]?.string == name {
                drop.server = server
                drop.log.debug("Using server '\(name)'.")
            } else {
                drop.log.debug("Not using server '\(name)'.")
            }
        }
    }

//    public func addConfigurable(server: ServerProtocol.Type, name: String) {
//        if config["droplet", "server"]?.string == name {
//            self.server = server
//            log.debug("Using server '\(name)'.")
//        } else {
//            log.debug("Not using server '\(name)'.")
//        }
//    }
}

// MARK: Client

import Transport

extension Droplet {
    public func addConfigurable(client: ClientProtocol.Type, name: String) {
        _addConfigurable(path: "droplet.client") { drop in
            if drop.config["droplet", "client"]?.string == name {
                drop.client = client
                drop.log.debug("Using client '\(name)'.")

                if let tls = drop.config["clients", "tls"]?.object {
                    defaultClientConfig = {
                        return try self.parseTLSConfig(tls, mode: .client)
                    }
                }
            } else {
                drop.log.debug("Not using client '\(name)'.")
            }
        }
    }

//    public func addConfigurable(client: ClientProtocol.Type, name: String) {
//        if config["droplet", "client"]?.string == name {
//            self.client = client
//            log.debug("Using client '\(name)'.")
//
//            if let tls = config["clients", "tls"]?.object {
//                defaultClientConfig = {
//                    return try self.parseTLSConfig(tls, mode: .client)
//                }
//            }
//        } else {
//            log.debug("Not using client '\(name)'.")
//        }
//    }
}



// MARK: Log

extension Droplet {
    public func addConfigurable(log: LogProtocol, name: String) {
        _addConfigurable(path: "droplet.log") { drop in
            if drop.config["droplet", "log"]?.string == name {
                drop.log = log
                drop.log.debug("Using log '\(name)'.")
            } else {
                drop.log.debug("Not using log '\(name)'.")
            }
        }
    }

    public func addConfigurable<L: LogProtocol & ConfigInitializable>(log: L.Type, name: String) throws {
        try _addConfigurable(path: "droplet.log") { drop in
            if drop.config["droplet", "log"]?.string == name {
                drop.log = try log.init(config: drop.config)
                drop.log.debug("Using log '\(name)'.")
            } else {
                drop.log.debug("Not using log '\(name)'.")
            }
        }
    }

//    public func addConfigurable(log: LogProtocol, name: String) {
//        if config["droplet", "log"]?.string == name {
//            self.log = log
//            self.log.debug("Using log '\(name)'.")
//        } else {
//            self.log.debug("Not using log '\(name)'.")
//        }
//    }
//
//    public func addConfigurable<L: LogProtocol & ConfigInitializable>(log: L.Type, name: String) throws {
//        if config["droplet", "log"]?.string == name {
//            self.log = try log.init(config: config)
//            self.log.debug("Using log '\(name)'.")
//        } else {
//            self.log.debug("Not using log '\(name)'.")
//        }
//    }
}

// MARK: Hash

extension Droplet {
    public func addConfigurable(hash: HashProtocol, name: String) {
        _addConfigurable(path: "droplet.hash") { drop in
            if drop.config["droplet", "hash"]?.string == name {
                drop.hash = hash
                drop.log.debug("Using hash '\(name)'.")
            } else {
                drop.log.debug("Not using hash '\(name)'.")
            }
        }
    }

    public func addConfigurable<H: HashProtocol & ConfigInitializable>(hash: H.Type, name: String) throws {
        try _addConfigurable(path: "droplet.hash") { drop in
            if drop.config["droplet", "hash"]?.string == name {
                drop.hash = try hash.init(config: drop.config)
                drop.log.debug("Using hash '\(name)'.")
            } else {
                drop.log.debug("Not using hash '\(name)'.")
            }
        }
    }
//    public func addConfigurable(hash: HashProtocol, name: String) {
//        if config["droplet", "hash"]?.string == name {
//            self.hash = hash
//            log.debug("Using hash '\(name)'.")
//        } else {
//            log.debug("Not using hash '\(name)'.")
//        }
//    }
//
//    public func addConfigurable<H: HashProtocol & ConfigInitializable>(hash: H.Type, name: String) throws {
//        if config["droplet", "hash"]?.string == name {
//            self.hash = try hash.init(config: config)
//            log.debug("Using hash '\(name)'.")
//        } else {
//            log.debug("Not using hash '\(name)'.")
//        }
//    }
}

// MARK: Cipher

extension Droplet {
    public func addConfigurable(cipher: CipherProtocol, name: String) {
        _addConfigurable(path: "droplet.cipher") { drop in
            if drop.config["droplet", "cipher"]?.string == name {
                drop.cipher = cipher
                drop.log.debug("Using cipher '\(name)'.")
            } else {
                drop.log.debug("Not using cipher '\(name)'.")
            }
        }
    }

    public func addConfigurable<C: CipherProtocol & ConfigInitializable>(cipher: C.Type, name: String) throws {
        try _addConfigurable(path: "droplet.cipher") { drop in
            if drop.config["droplet", "cipher"]?.string == name {
                drop.cipher = try cipher.init(config: drop.config)
                drop.log.debug("Using cipher '\(name)'.")
            } else {
                drop.log.debug("Not using cipher '\(name)'.")
            }
        }
    }

//    public func addConfigurable(cipher: CipherProtocol, name: String) {
//        if config["droplet", "cipher"]?.string == name {
//            self.cipher = cipher
//            log.debug("Using cipher '\(name)'.")
//        } else {
//            log.debug("Not using cipher '\(name)'.")
//        }
//    }
//
//    public func addConfigurable<C: CipherProtocol & ConfigInitializable>(cipher: C.Type, name: String) throws {
//        if config["droplet", "cipher"]?.string == name {
//            self.cipher = try cipher.init(config: config)
//            log.debug("Using cipher '\(name)'.")
//        } else {
//            log.debug("Not using cipher '\(name)'.")
//        }
//    }
}

// MARK: Middleware

import HTTP

extension Droplet {
    public func addConfigurable(middleware: Middleware, name: String) {
        _addConfigurable(path: "droplet.middleware") { drop in
            if drop.config["droplet", "middleware", "server"]?.array?.flatMap({ $0.string }).contains(name) == true {
                drop.middleware.append(middleware)
                drop.log.debug("Using server middleware '\(name)'.")
            } else {
                drop.log.debug("Not using server middleware '\(name)'.")
            }

            if drop.config["droplet", "middleware", "client"]?.array?.flatMap({ $0.string }).contains(name) == true {
                let cm = drop.client.defaultMiddleware
                drop.client.defaultMiddleware = cm + [middleware]
                drop.log.debug("Using client middleware '\(name)'.")
            } else {
                drop.log.debug("Not using client middleware '\(name)'.")
            }
        }
    }

//    public func addConfigurable(middleware: Middleware, name: String) {
//        if config["droplet", "middleware", "server"]?.array?.flatMap({ $0.string }).contains(name) == true {
//            self.middleware.append(middleware)
//            log.debug("Using server middleware '\(name)'.")
//        } else {
//            log.debug("Not using server middleware '\(name)'.")
//        }
//
//        if config["droplet", "middleware", "client"]?.array?.flatMap({ $0.string }).contains(name) == true {
//            let cm = self.client.defaultMiddleware
//            self.client.defaultMiddleware = cm + [middleware]
//            log.debug("Using client middleware '\(name)'.")
//        } else {
//            log.debug("Not using client middleware '\(name)'.")
//        }
//    }
}

// MARK: Console

import Console

extension Droplet {
    public func addConfigurable(console: ConsoleProtocol, name: String) {
        _addConfigurable(path: "droplet.console") { drop in
            if drop.config["droplet", "console"]?.string == name {
                drop.console = console
                drop.log.debug("Using console '\(name)'.")
            } else {
                drop.log.debug("Not using console '\(name)'.")
            }
        }
    }

    public func addConfigurable<C: ConsoleProtocol & ConfigInitializable>(console: C.Type, name: String) throws {
        try _addConfigurable(path: "droplet.console") { drop in
            if drop.config["droplet", "console"]?.string == name {
                drop.console = try console.init(config: drop.config)
                drop.log.debug("Using console '\(name)'.")
            } else {
                drop.log.debug("Not using console '\(name)'.")
            }
        }
    }
//    public func addConfigurable(console: ConsoleProtocol, name: String) {
//        if config["droplet", "console"]?.string == name {
//            self.console = console
//            log.debug("Using console '\(name)'.")
//        } else {
//            log.debug("Not using console '\(name)'.")
//        }
//    }
//
//    public func addConfigurable<C: ConsoleProtocol & ConfigInitializable>(console: C.Type, name: String) throws {
//        if config["droplet", "console"]?.string == name {
//            self.console = try console.init(config: config)
//            log.debug("Using console '\(name)'.")
//        } else {
//            log.debug("Not using console '\(name)'.")
//        }
//    }
}

// MARK: Cache

import Cache

extension Droplet {
    public func addConfigurable(cache: CacheProtocol, name: String) {
        _addConfigurable(path: "droplet.cache") { drop in
            if drop.config["droplet", "cache"]?.string == name {
                drop.cache = cache
                drop.log.debug("Using cache '\(name)'.")
            } else {
                drop.log.debug("Not using cache '\(name)'.")
            }
        }
    }

    public func addConfigurable<C: CacheProtocol & ConfigInitializable>(cache: C.Type, name: String) throws {
        try _addConfigurable(path: "droplet.cache") { drop in
            if drop.config["droplet", "cache"]?.string == name {
                drop.cache = try cache.init(config: drop.config)
                drop.log.debug("Using cache '\(name)'.")
            } else {
                drop.log.debug("Not using cache '\(name)'.")
            }
        }
    }

//    public func addConfigurable(cache: CacheProtocol, name: String) {
//        if config["droplet", "cache"]?.string == name {
//            self.cache = cache
//            log.debug("Using cache '\(name)'.")
//        } else {
//            log.debug("Not using cache '\(name)'.")
//        }
//    }
//
//    public func addConfigurable<C: CacheProtocol & ConfigInitializable>(cache: C.Type, name: String) throws {
//        if config["droplet", "cache"]?.string == name {
//            self.cache = try cache.init(config: config)
//            log.debug("Using cache '\(name)'.")
//        } else {
//            log.debug("Not using cache '\(name)'.")
//        }
//    }
}
