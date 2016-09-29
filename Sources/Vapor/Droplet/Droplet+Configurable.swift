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
        do {
            if config["droplet", "log"]?.string == name {
                self.log = try log.init(config: config)
                self.log.debug("Using log '\(name)'.")
            } else {
                self.log.debug("Not using log '\(name)'.")
            }
        } catch {
            self.log.warning("Could not configure log '\(name)': \(error)")
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

    public func addConfigurable<H: HashProtocol & ConfigInitializable>(hash: H.Type, name: String) {
        do {
            if config["droplet", "hash"]?.string == name {
                self.hash = try hash.init(config: config)
                log.debug("Using hash '\(name)'.")
            } else {
                log.debug("Not using hash '\(name)'.")
            }
        } catch {
            log.warning("Could not configure hash '\(name)': \(error)")
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

    public func addConfigurable<C: CipherProtocol & ConfigInitializable>(cipher: C.Type, name: String) {
        do {
            if config["droplet", "cipher"]?.string == name {
                self.cipher = try cipher.init(config: config)
                log.debug("Using cipher '\(name)'.")
            } else {
                log.debug("Not using cipher '\(name)'.")
            }
        } catch {
            log.warning("Could not configure cipher '\(name)': \(error)")
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
        } else if config["middleware", "server"]?.array?.flatMap({ $0.string }).contains(name) == true {
            self.middleware.append(middleware)

            log.warning("[DEPRECATED] Key `server` in `middleware.json` will be removed in a future update. Use key `middleware.server` in `droplet.json`.")
            log.debug("Using server middleware '\(name)'.")
        } else {
            log.debug("Not using server middleware '\(name)'.")
        }

        if config["droplet", "middleware", "client"]?.array?.flatMap({ $0.string }).contains(name) == true {
            let cm = self.client.defaultMiddleware
            self.client.defaultMiddleware = cm + [middleware]

            log.debug("Using client middleware '\(name)'.")
        } else if config["middleware", "client"]?.array?.flatMap({ $0.string }).contains(name) == true {
            let cm = self.client.defaultMiddleware // FIXME: Weird Swift 3 BAD_ACCESS crash if not like this
            self.client.defaultMiddleware = cm + [middleware]

            log.warning("[DEPRECATED] Key `client` in `middleware.json` will be removed in a future update. Use key `middleware.client` in `droplet.json`.")
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

    public func addConfigurable<C: ConsoleProtocol & ConfigInitializable>(console: C.Type, name: String) {
        do {
            if config["droplet", "console"]?.string == name {
                self.console = try console.init(config: config)
                log.debug("Using console '\(name)'.")
            } else {
                log.debug("Not using console '\(name)'.")
            }
        } catch {
            log.warning("Could not configure console  '\(name)': \(error)")
        }
    }
}
