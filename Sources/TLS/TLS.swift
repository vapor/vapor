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
    var peerDomainName: String? { get set }
    
    func connect(hostname: String, port: UInt16) throws -> Future<Void>
}

public protocol TLSClient: TLSSocket {
    var settings: TLSClientSettings { get set }
}

public protocol TLSServer: TLSSocket {
    var settings: TLSServerSettings { get set }
}

public protocol ALPNSupporting: TLSSocket {
    var ALPNprotocols: [String] { get set }
    var selectedProtocol: String? { get }
}

public protocol TLSStream: TLSSocket, Async.Stream where Input == ByteBuffer, Output == ByteBuffer {
    /// Input will be passed here as it is received.
    func onInput(_ input: ByteBuffer)
    
    /// Errors will be passed here as it is received.
    func onError(_ error: Error)
    
    /// Send output to the provided input stream.
    func onOutput<I: InputStream>(_ input: I) where I.Input == ByteBuffer
}

public protocol BasicTLSUpgrader {
    func upgrade(socket: TCPSocket) throws -> Future<BasicTLSClient>
}

public final class BasicTLSClient: TLSClient, TLSStream {
    public var settings: TLSClientSettings
    
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
    
    public init<Socket: TLSStream & TLSClient>(boxing socket: Socket, settings: TLSClientSettings) {
        self.client = socket
        self.process = socket.onInput
        self.settings = settings
        self.alpnSupporting = socket as? ALPNSupporting
    }
}
