import Async
import Bits
import Dispatch

public struct TLSClientSettings {
    public init() {}
    
    public var clientCertificate: String?
    public var trustedCAFilePaths = [String]()
    public var peerDomainName: String?
}

public struct TLSServerSettings {
    public init(serverCertificate: String) {
        self.serverCertificate = serverCertificate
    }
    
    public var serverCertificate: String
}

public enum TLSSide {
    case client(TLSClientSettings)
    case server(TLSServerSettings)
}

public protocol TLSConnection: Async.Stream where Input == ByteBuffer, Output == ByteBuffer {
    var peerDomainName: String? { get set }
    
    func connect(hostname: String, port: UInt16) throws -> Future<Void>
}

public protocol ALPNSupporting: TLSConnection {
    var ALPNprotocols: [String] { get set }
    var selectedProtocol: String? { get }
}
