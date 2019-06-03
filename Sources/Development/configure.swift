import Vapor

public func configure(_ s: inout Services) throws {
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
