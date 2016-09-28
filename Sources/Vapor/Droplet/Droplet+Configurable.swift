// MARK: Hash

extension Droplet {
    public func addConfigurable(hash: HashProtocol, name: String) {
        if config["crypto", "hash", "method"]?.string == name {
            self.hash = hash
        }
    }

    public func addConfigurable<H: HashProtocol & ConfigInitializable>(hash: H.Type, name: String) throws {
        if config["crypto", "hash", "method"]?.string == name {
            self.hash = try hash.init(config: config)
        }
    }
}

// MARK: Cipher

extension Droplet {
    public func addConfigurable(cipher: CipherProtocol, name: String) {
        if config["crypto", "cipher", "method"]?.string == name {
            self.cipher = cipher
        }
    }

    public func addConfigurable<C: CipherProtocol & ConfigInitializable>(cipher: C.Type, name: String) throws {
        if config["crypto", "cipher", "method"]?.string == name {
            self.cipher = try cipher.init(config: config)
        }
    }
}

// MARK: Middleware

import HTTP

extension Droplet {
    public func addConfigurable(middleware: Middleware, name: String) {
        if config["middleware", "server"]?.array?.flatMap({ $0.string }).contains(name) == true {
            self.middleware.append(middleware)
        }

        if config["middleware", "client"]?.array?.flatMap({ $0.string }).contains(name) == true {
            self.client.defaultMiddleware.append(middleware)
        }
    }
}
