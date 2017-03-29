// MARK: Server

extension Droplet {
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
        let config = self.config.converted(to: Node.self)

        if config["droplet", "client"]?.string == name {
            self.client = client
            log.debug("Using client '\(name)'.")

            if let tls = config["clients", "tls"]?.object {
                EngineClient.defaultTLSContext = {
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
        if config["droplet", "middleware"]?.array?.flatMap({ $0.string }).contains(name) == true {
            self.middleware.append(middleware)
            log.debug("Using middleware '\(name)'.")
        } else {
            log.debug("Not using middleware '\(name)'.")
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
