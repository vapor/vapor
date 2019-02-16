import Vapor

public func configure(_ s: inout Services) throws {
    s.extend(Routes.self) { r, c in
        try routes(r, c)
    }
    
    s.register(HTTPServerConfig.self) { c in
        switch c.env {
        case .tls:
            return HTTPServerConfig(
                hostname: "127.0.0.1",
                port: 8443,
                tlsConfig: .forServer(
                    certificateChain: [.file("/Users/tanner0101/dev/vapor/net-kit/certs/cert.pem")],
                    privateKey: .file("/Users/tanner0101/dev/vapor/net-kit/certs/key.pem")
                )
            )
        default:
            return HTTPServerConfig(
                hostname: "127.0.0.1",
                port: 8080
            )
        }
    }
}

extension Environment {
    static var tls: Environment {
        return .custom(name: "tls")
    }
}
