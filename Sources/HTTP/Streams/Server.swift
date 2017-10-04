import Async
import TCP

/// HTTP server wrapped around TCP server
public final class Server<ClientStream: OutputStream>: Async.OutputStream where ClientStream.Output == TCP.Client {
    // MARK: Stream
    public typealias Output = HTTP.Peer
    
    /// See `BaseStream.errorStream`
    public var errorStream: ErrorHandler? {
        get { return clientStream.errorStream }
        set { clientStream.errorStream = newValue }
    }

    /// See `OutputStream.outputStream`
    public var outputStream: OutputHandler?

    /// The wrapped Client Stream
    public let clientStream: ClientStream

    /// Creates a new HTTP Server from a Client stream
    public init(clientStream: ClientStream) {
        self.clientStream = clientStream
        clientStream.outputStream = { tcp in
            let client = HTTP.Peer(tcp: tcp)
            self.outputStream?(client)
        }
    }
}
