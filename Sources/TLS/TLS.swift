import Async
import TCP
import Bits
import Dispatch

public protocol TLSSocket {
    func read(max: Int, into buffer: MutableByteBuffer) throws -> Int
    func write(max: Int, from buffer: ByteBuffer) throws -> Int
    func close()
}

public protocol TLSClient {
    var settings: TLSClientSettings { get }
    func connect(hostname: String, port: UInt16) throws
}

// replace with TLSDataStream
// public protocol TLSStream: TLSSocket, Async.Stream where Input == ByteBuffer, Output == ByteBuffer {}

/// MARK: Peer

public protocol TLSPeer: TLSSocket {
    var settings: TLSServerSettings { get set }
}

/// MARK: Upgraders

public protocol TLSClientUpgrader {
    func upgrade(socket: TCPSocket, settings: TLSClientSettings, eventLoop: EventLoop) throws -> Future<TLSClient>
}

public protocol TLSPeerUpgrader {
    func upgrade(socket: TCPSocket, settings: TLSServerSettings, eventLoop: EventLoop) throws -> Future<TLSPeer>
}

/// MARK: Settings

public struct TLSClientSettings {
    public let clientCertificate: String?
    public let trustedCAFilePaths: [String]
    public let peerDomainName: String?

    public init(
        clientCertificate: String? = nil,
        trustedCAFilePaths: [String] = [],
        peerDomainName: String? = nil
    ) {
        self.clientCertificate = clientCertificate
        self.trustedCAFilePaths = trustedCAFilePaths
        self.peerDomainName = peerDomainName
    }
}

public struct TLSServerSettings {
    public let hostname: String
    public let privateKey: String
    public let publicKey: String

    public init(hostname: String, publicKey: String, privateKey: String) {
        self.hostname = hostname
        self.publicKey = publicKey
        self.privateKey = privateKey
    }
}

public protocol ALPNSupporting: TLSSocket {
    var ALPNprotocols: [String] { get set }
    var selectedProtocol: String? { get }
}
