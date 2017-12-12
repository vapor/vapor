import Async
import TCP
import Bits
import Dispatch

public final class BasicSSLPeer: SSLPeer, TLSStream {
    public var settings: SSLServerSettings {
        get {
            return peer.settings
        }
        set {
            peer.settings = newValue
        }
    }
    
    let peer: SSLPeer
    public let alpnSupporting: ALPNSupporting?
    public var peerDomainName: String?
    
    let outputStream = BasicStream<ByteBuffer>()
    
    public typealias Input = ByteBuffer
    public typealias Output = ByteBuffer
    
    public func onInput(_ input: ByteBuffer) {
        peer.onInput(input)
    }
    
    public func onError(_ error: Error) {
        peer.onError(error)
    }
    
    public func onOutput<I>(_ input: I) where I : InputStream, Output == I.Input {
        peer.onOutput(input)
    }
    
    public func close() {
        peer.close()
    }
    
    public func onClose(_ onClose: ClosableStream) {
        peer.onClose(onClose)
    }
    
    public init<Socket: TLSStream & SSLPeer>(boxing socket: Socket) {
        self.peer = socket
        self.alpnSupporting = socket as? ALPNSupporting
    }
}


