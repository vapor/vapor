import Vapor

public func configure(_ s: inout Services) throws {
    s.extend(Routes.self) { r, c in
        try routes(r, c)
    }
    
    s.register(HTTPServersConfig.self) { c in
        let plaintext = HTTPServerConfig(hostname: "127.0.0.1", port: 8080)
        let tls = HTTPServerConfig(hostname: "127.0.0.1", port: 8443, tlsConfig: .forServer(
            certificateChain: [.file("/Users/tanner0101/dev/vapor/http/certs/cert.pem")],
            privateKey: .file("/Users/tanner0101/dev/vapor/http/certs/key.pem")
        ))
        return HTTPServersConfig(servers: [plaintext, tls])
    }
}
