public enum ProgramStreamError: ErrorProtocol {
    case unsupportedSecurityLayer
}

public protocol ProgramStream {
    var host: String { get }
    var port: Int { get }
    var securityLayer: SecurityLayer { get }
    init(host: String, port: Int, securityLayer: SecurityLayer) throws
}

extension ProgramStream {
    init(host: String, port: Int) throws {
        try self.init(host: host, port: port, securityLayer: .none)
    }
}

public enum SecurityLayer {
    case none, tls
}

extension String {
    var securityLayer: SecurityLayer {
        if self == "https" || self == "wss" {
            return .tls
        } else {
            return .none
        }
    }
}
