import Vapor

public func configure(_ app: Application) throws {
    app.server.configuration.hostname = "127.0.0.1"
    switch app.environment {
    case .tls:
        app.server.configuration.port = 8443
        try app.server.configuration.tlsConfiguration = .forServer(
            certificateChain: [
                .certificate(.init(
                    file: "/Users/tanner0101/dev/vapor/net-kit/certs/cert.pem",
                    format: .pem
                ))
            ],
            privateKey: .file("/Users/tanner0101/dev/vapor/net-kit/certs/key.pem")
        )
    default:
        app.server.configuration.port = 8080
    }
    
    // routes
    try routes(app)
}

final class MemoryCache {
    var storage: [String: String]
    var lock: Lock

    init() {
        self.storage = [:]
        self.lock = .init()
    }

    func get(_ key: String) -> String? {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.storage[key]
    }

    func set(_ key: String, to value: String?) {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.storage[key] = value
    }
}

extension Environment {
    static var tls: Environment {
        return .custom(name: "tls")
    }
}
