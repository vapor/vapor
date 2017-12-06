import Async
import TCP
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

public protocol TLSSocket: ClosableStream {
    
}

public protocol TLSClient: TLSSocket {
    var settings: TLSClientSettings { get set }
    var peerDomainName: String? { get set }
    
    func connect(hostname: String, port: UInt16) throws -> Future<Void>
}

public protocol TLSServer: TLSSocket {
    var settings: TLSServerSettings { get set }
}

public protocol ALPNSupporting: TLSSocket {
    var ALPNprotocols: [String] { get set }
    var selectedProtocol: String? { get }
}

public protocol TLSStream: TLSSocket, Async.Stream where Input == ByteBuffer, Output == ByteBuffer {}

public protocol BasicTLSClientUpgrader {
    func upgrade(socket: TCPSocket) throws -> Future<BasicTLSClient>
}

//public protocol BasicTLSPeerUpgrader {
//    func upgrade(socket: TCPSocket) throws -> Future<BasicTLSPeer>
//}

public final class BasicTLSClient: TLSClient, TLSStream {
    public var settings: TLSClientSettings {
        get {
            return client.settings
        }
        set {
            client.settings = newValue
        }
    }
    
    let client: TLSClient
    public let alpnSupporting: ALPNSupporting?
    public var peerDomainName: String?
    
    let outputStream = BasicStream<ByteBuffer>()
    var process: ((ByteBuffer) -> ())
    
    public typealias Input = ByteBuffer
    public typealias Output = ByteBuffer
    
    public func onInput(_ input: ByteBuffer) {
        process(input)
    }
    
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }
    
    public func onOutput<I>(_ input: I) where I : InputStream, Output == I.Input {
        outputStream.onOutput(input)
    }
    
    public func close() {
        outputStream.close()
    }
    
    public func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
    }
    
    public func connect(hostname: String, port: UInt16) throws -> Future<Void> {
        return try client.connect(hostname: hostname, port: port)
    }
    
    public init<Socket: TLSStream & TLSClient>(boxing socket: Socket) {
        self.client = socket
        self.process = socket.onInput
        self.alpnSupporting = socket as? ALPNSupporting
    }
}
