import Async
import TCP

/// HTTP server wrapped around TCP server
public final class Server<ClientStream: OutputStream>: Async.OutputStream where ClientStream.Output == TCP.Client {
    // MARK: Stream
    public typealias Output = HTTP.Peer
    
    /// See `BaseStream.onClose`
    public var onClose: CloseHandler? {
        get {
            return tcp.onClose
        }
        set {
            tcp.onClose = newValue
        }
    }
    
    /// See `BaseStream.errorStream`
    public var errorStream: ErrorHandler? {
        get { return tcp.errorStream }
        set { tcp.errorStream = newValue }
    }

    /// See `OutputStream.outputStream`
    public var outputStream: OutputHandler?

    /// The wrapped Client Stream
    public let tcp: ClientStream

    /// Creates a new HTTP Server from a Client stream
    public init(tcp: ClientStream) {
        self.tcp = tcp
        tcp.outputStream = { tcp in
            let client = HTTP.Peer(tcp: tcp)
            self.outputStream?(client)
        }
    }
}
