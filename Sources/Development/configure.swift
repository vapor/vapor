import Vapor

public func configure(_ s: inout Services) throws {
    s.extend(Routes.self) { r, c in
        try routes(r, c)
    }
    
    s.register(HTTPServer.Configuration.self) { c in
        switch c.environment {
        case .tls:
            return .init(hostname: "127.0.0.1", port: 8443, tlsConfiguration: tls)
        default:
            return .init(hostname: "127.0.0.1", port: 8080)
        }
    }
}

let tls = TLSConfiguration.forServer(
    certificateChain: [.file("/Users/tanner0101/dev/vapor/net-kit/certs/cert.pem")],
    privateKey: .file("/Users/tanner0101/dev/vapor/net-kit/certs/key.pem")
)

extension Environment {
    static var tls: Environment {
        return .custom(name: "tls")
    }
}
