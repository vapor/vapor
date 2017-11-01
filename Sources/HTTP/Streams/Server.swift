import Async
import TCP

/// HTTP server wrapped around TCP server
public final class Server<ClientStream: OutputStream>: Async.OutputStream where ClientStream.Notification == TCPClient {
    // MARK: Stream
    public typealias Notification = HTTP.Peer
    
    /// See `BaseStream.errorNotification`
    public var errorNotification: SingleNotification<Error> {
        return self.clientStream.errorNotification
    }

    /// See `OutputStream.outputStream`
    public var outputStream: NotificationCallback?

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
