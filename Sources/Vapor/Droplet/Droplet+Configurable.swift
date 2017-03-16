import Settings

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

public struct ConfigErrorList: Error {
    public let errors: [Error]

    public init(_ errors: [Error]) {
        self.errors = errors
    }
}

extension Droplet {
    func configDidUpdate(original: Config, new: Config) throws {
        let configurables = self.configurables

        let (additions, updates, subtractions) = try original.changes(comparedTo: new)

        var errors = [Error]()

        let handler: (Configurable) -> Void = { configurable in
            do { try configurable(self) }
            catch { errors.append(error) }
        }

        let flatMap: (String) -> [Configurable] = { modification in
            // use prefix incase nested values change, ie: 
            // if I listen for `foo.bar` and `foo.bar.val` changes, 
            // I should get an update trigger
            return configurables.filter { path, _ in modification.hasPrefix(path) }
                .map { _, configurable in return configurable }
        }

        subtractions.flatMap(flatMap).forEach(handler)
        updates.flatMap(flatMap).forEach(handler)
        additions.flatMap(flatMap).forEach(handler)

        if !errors.isEmpty { throw ConfigErrorList(errors) }
    }
}


extension StructuredDataWrapper {
    var isObject: Bool {
        return typeObject != nil
    }
}

typealias Configurable = (Droplet) throws -> Void

extension Droplet {
    /// when adding new configurable, if path already in config
    /// On path updates, we trigger the runner again,
    /// could pass 'updated', 'added', 'removed' possibly
    ///
    /// on addConfigurable, if path exists, trigger runner,
    /// on configuration updates, trigger appropriate runners
    private(set) var configurables: [(String, Configurable)] {
        get {
            return storage["_configurables"] as? [(String, Configurable)]
                ?? []
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

        configurables.append((path, configurable))
    }

    func _addConfigurable(path: String, configurable: @escaping Configurable) throws {
        // If the path already exists in config, configure now
        if let _ = config[path] {
            try configurable(self)
        }

        configurables.append((path, configurable))
    }
}


// MARK: Server

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
}
