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

public struct TLSServerSettings {
    public init(serverCertificate: String) {
        self.serverCertificate = serverCertificate
    }
    
    public var serverCertificate: String
}

public enum TLSSide {
    case client(SSLClientSettings)
    case server(TLSServerSettings)
}

public protocol TLSSocket: ClosableStream {
    func onError(_ error: Error)
    func onInput(_ input: ByteBuffer)
    func onOutput<I>(_ input: I) where I : InputStream, I.Input == ByteBuffer
}

public protocol SSLClient: TLSSocket {
    var settings: SSLClientSettings { get set }
    var peerDomainName: String? { get set }
    
    func connect(hostname: String, port: UInt16) throws -> Completable
}

public protocol TLSServer: TLSSocket {
    var settings: TLSServerSettings { get set }
}

public protocol ALPNSupporting: TLSSocket {
    var ALPNprotocols: [String] { get set }
    var selectedProtocol: String? { get }
}

public protocol TLSStream: TLSSocket, Async.Stream where Input == ByteBuffer, Output == ByteBuffer {}

public protocol BasicSSLClientUpgrader {
    func upgrade(socket: TCPSocket, settings: SSLClientSettings) throws -> Future<BasicSSLClient>
}

public final class BasicSSLClient: SSLClient, TLSStream {
    public var settings: SSLClientSettings {
        get {
            return client.settings
        }
        set {
            client.settings = newValue
        }
    }
    
    let client: SSLClient
    public let alpnSupporting: ALPNSupporting?
    public var peerDomainName: String?
    
    let outputStream = BasicStream<ByteBuffer>()
    
    public typealias Input = ByteBuffer
    public typealias Output = ByteBuffer
    
    public func onInput(_ input: ByteBuffer) {
        client.onInput(input)
    }
    
    public func onError(_ error: Error) {
        client.onError(error)
    }
    
    public func onOutput<I>(_ input: I) where I : InputStream, Output == I.Input {
        client.onOutput(input)
    }
    
    public func close() {
        client.close()
    }
    
    public func onClose(_ onClose: ClosableStream) {
        client.onClose(onClose)
    }
    
    public func connect(hostname: String, port: UInt16) throws -> Completable {
        client.peerDomainName = hostname
        return try client.connect(hostname: hostname, port: port)
    }
    
    public init<Socket: TLSStream & SSLClient>(boxing socket: Socket) {
        self.client = socket
        self.alpnSupporting = socket as? ALPNSupporting
    }
}
