public protocol Program {
    var host: String { get }
    var port: Int { get }
    var securityLayer: SecurityLayer { get }
    init(host: String, port: Int, securityLayer: SecurityLayer) throws
}

extension Program {
    public static func make(
        host: String? = nil,
        port: Int? = nil,
        securityLayer: SecurityLayer = .tls
    )  throws -> Self {
        let host = host ?? "0.0.0.0"
        let port = port ?? (securityLayer == .tls ? 443 : 80)
        return try Self(host: host, port: port, securityLayer: securityLayer)
    }
}

extension Program {
    public static func make(
        scheme: String? = nil,
        host: String,
        port: Int? = nil
    ) throws -> Self {
        let scheme = scheme ?? "https" // default to secure https connection
        let port = port ?? URI.defaultPorts[scheme] ?? 80
        return try Self(host: host, port: port, securityLayer: scheme.securityLayer)
    }
}
