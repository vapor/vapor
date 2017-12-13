import Async
import TCP
import Bits
import Dispatch

//public final class BasicSSLClient: SSLClient, TLSStream {
//    public var settings: SSLClientSettings {
//        get {
//            return client.settings
//        }
//        set {
//            client.settings = newValue
//        }
//    }
//    
//    let client: SSLClient
//    public let alpnSupporting: ALPNSupporting?
//    public var peerDomainName: String?
//    
//    let outputStream = BasicStream<ByteBuffer>()
//    
//    public typealias Input = ByteBuffer
//    public typealias Output = ByteBuffer
//    
//    public func onInput(_ input: ByteBuffer) {
//        client.onInput(input)
//    }
//    
//    public func onError(_ error: Error) {
//        client.onError(error)
//    }
//    
//    public func onOutput<I>(_ input: I) where I : InputStream, Output == I.Input {
//        client.onOutput(input)
//    }
//    
//    public func close() {
//        client.close()
//    }
//    
//    public func onClose(_ onClose: ClosableStream) {
//        client.onClose(onClose)
//    }
//    
//    public func connect(hostname: String, port: UInt16) throws -> Future<Void> {
//        client.peerDomainName = hostname
//        return try client.connect(hostname: hostname, port: port)
//    }
//    
//    public init<Socket: TLSStream & SSLClient>(boxing socket: Socket) {
//        self.client = socket
//        self.alpnSupporting = socket as? ALPNSupporting
//    }
//}

