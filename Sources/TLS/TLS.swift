import Async
import TCP
import Bits
import Dispatch

public struct SSLClientSettings {
    public init() {}
    
    public var clientCertificate: String?
    public var trustedCAFilePaths = [String]()
    public var peerDomainName: String?
}

public struct SSLServerSettings {
    public init(hostname: String, publicKey: String, privateKey: String) {
        self.hostname = hostname
        self.publicKey = publicKey
        self.privateKey = privateKey
    }
    
    public var hostname: String
    public var privateKey: String
    public var publicKey: String
}

public protocol TLSSocket: ClosableStream {
    func onError(_ error: Error)
    func onInput(_ input: ByteBuffer)
    func onOutput<I>(_ input: I) where I : InputStream, I.Input == ByteBuffer
}

public protocol SSLClient: TLSSocket {
    var settings: SSLClientSettings { get set }
    var peerDomainName: String? { get set }
    
    func connect(hostname: String, port: UInt16) throws -> Future<Void>
}

public protocol SSLPeer: TLSSocket {
    var settings: SSLServerSettings { get set }
}

public protocol ALPNSupporting: TLSSocket {
    var ALPNprotocols: [String] { get set }
    var selectedProtocol: String? { get }
}

public protocol TLSStream: TLSSocket, Async.Stream where Input == ByteBuffer, Output == ByteBuffer {}

public protocol SSLClientUpgrader {
    func upgrade(socket: TCPSocket, settings: SSLClientSettings, eventLoop: EventLoop) throws -> Future<BasicSSLClient>
}

public protocol SSLPeerUpgrader {
    func upgrade(socket: TCPSocket, settings: SSLServerSettings, eventLoop: EventLoop) throws -> Future<BasicSSLPeer>
}
