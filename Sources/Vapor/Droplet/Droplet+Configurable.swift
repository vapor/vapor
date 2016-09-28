// MARK: Log

extension Droplet {
    public func addConfigurable(log: LogProtocol, name: String) {
        if config["droplet", "log"]?.string == name {
            self.log = log
        }
    }

    public func addConfigurable<L: LogProtocol & ConfigInitializable>(log: L.Type, name: String) throws {
        if config["droplet", "log"]?.string == name {
            self.log = try log.init(config: config)
        }
    }
}

// MARK: Hash

extension Droplet {
    public func addConfigurable(hash: HashProtocol, name: String) {
        if config["crypto", "hash", "method"]?.string == name {
            log.warning("[DEPRECATED] Key `hash.method` in `crypto.json` will be removed in a future update. Use key `hash` in `droplet.json`.")
            self.hash = hash
        }
        if config["droplet", "hash"]?.string == name {
            self.hash = hash
        }
    }

    public func addConfigurable<H: HashProtocol & ConfigInitializable>(hash: H.Type, name: String) throws {
        if config["crypto", "hash", "method"]?.string == name {
            log.warning("[DEPRECATED] `hash.method` in `crypto.json` will be removed in a future update. Use key `hash` in `droplet.json`.")
            self.hash = try hash.init(config: config)
        }
        if config["droplet", "hash"]?.string == name {
            self.hash = try hash.init(config: config)
        }
    }
}

// MARK: Cipher

extension Droplet {
    public func addConfigurable(cipher: CipherProtocol, name: String) {
        if config["crypto", "cipher", "method"]?.string == name {
            log.warning("[DEPRECATED] Key `cipher.method` in `crypto.json` will be removed in a future update. Use key `cipher` in `droplet.json`.")
            self.cipher = cipher
        }
        if config["droplet", "cipher"]?.string == name {
            self.cipher = cipher
        }
    }

    public func addConfigurable<C: CipherProtocol & ConfigInitializable>(cipher: C.Type, name: String) throws {
        if config["crypto", "cipher", "method"]?.string == name {
            log.warning("[DEPRECATED] Key `cipher.method` in `crypto.json` will be removed in a future update. Use key `cipher` in `droplet.json`.")
            self.cipher = try cipher.init(config: config)
        }

        if config["droplet", "cipher"]?.string == name {
            self.cipher = try cipher.init(config: config)
        }
    }
}

// MARK: Middleware

import HTTP

extension Droplet {
    public func addConfigurable(middleware: Middleware, name: String) {
        if config["middleware", "server"]?.array?.flatMap({ $0.string }).contains(name) == true {
            log.warning("[DEPRECATED] Key `server` in `middleware.json` will be removed in a future update. Use key `middleware.server` in `droplet.json`.")
            self.middleware.append(middleware)
        }
        if config["droplet", "middleware", "server"]?.array?.flatMap({ $0.string }).contains(name) == true {
            self.middleware.append(middleware)
        }

        if config["middleware", "client"]?.array?.flatMap({ $0.string }).contains(name) == true {
            log.warning("[DEPRECATED] Key `client` in `middleware.json` will be removed in a future update. Use key `middleware.client` in `droplet.json`.")
            let cm = self.client.defaultMiddleware // FIXME: Weird Swift 3 BAD_ACCESS crash if not like this
            self.client.defaultMiddleware = cm + [middleware]
        }
        if config["droplet", "middleware", "client"]?.array?.flatMap({ $0.string }).contains(name) == true {
            let cm = self.client.defaultMiddleware
            self.client.defaultMiddleware = cm + [middleware]
        }
    }
}

// MARK: Console

import Console

extension Droplet {
    public func addConfigurable(console: ConsoleProtocol, name: String) {
        if config["droplet", "console"]?.string == name {
            self.console = console
        }
    }

    public func addConfigurable<C: ConsoleProtocol & ConfigInitializable>(console: C.Type, name: String) throws {
        if config["droplet", "console"]?.string == name {
            self.console = try console.init(config: config)
        }
    }
}
