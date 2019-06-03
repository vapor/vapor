import Vapor

final class Development: ApplicationDelegate {
    init() { }
    
    func configure(_ s: inout Services) {
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
}
