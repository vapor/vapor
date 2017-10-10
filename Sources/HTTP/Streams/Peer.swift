import Async
import Dispatch
import Bits
import TCP

/// An HTTP `Server`'s peer wrapped around TCP client
public final class Peer: Async.Stream, ClosableStream {
    /// See `InputStream.Input`
    public typealias Input = DispatchData
    
    /// See `OutputStream.Output`
    public typealias Output = ByteBuffer
    
    /// See `BaseStream.onClose`
    public var onClose: CloseHandler? {
        get {
            return tcp.onClose
        }
        set {
            tcp.onClose = newValue
        }
    }
    
    /// See `OutputStream.OutputHandler`
    public var outputStream: OutputHandler? {
        get {
            return tcp.outputStream
        }
        set {
            tcp.outputStream = newValue
        }
    }
    
    /// See `OutputStream.errorStream`
    public var errorStream: ErrorHandler?
    
    /// The underlying TCP Client
    public let tcp: TCPClient
    
    /// Creates a new `Peer` from a `TCP.Client`
    public init(tcp: TCPClient) {
        self.tcp = tcp
    }
    
    /// Writes the serialized message and upgrades if necessary
    public func inputStream(_ input: DispatchData) {
        tcp.inputStream(input)
    }
    
    public func close() {
        tcp.close()
    }
}
