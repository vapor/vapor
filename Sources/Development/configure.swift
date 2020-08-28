import Vapor

public func configure(_ app: Application) throws {
    app.http.server.configuration.hostname = "127.0.0.1"
    switch app.environment.name {
    case .tls:
        app.http.server.configuration.port = 8443
        try app.http.server.configuration.tlsConfiguration = .forServer(
            certificateChain: [
                .certificate(.init(
                    file: "/Users/tanner0101/dev/vapor/net-kit/certs/cert.pem",
                    format: .pem
                ))
            ],
            privateKey: .file("/Users/tanner0101/dev/vapor/net-kit/certs/key.pem")
        )
    default:
        app.http.server.configuration.port = 8080
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

extension Environment.Name {
    static var tls: Self {
        .init(string: "tls")
    }
}
