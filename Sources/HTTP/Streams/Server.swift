import Async
import TCP

/// HTTP server wrapped around TCP server
public final class Server: Async.OutputStream {
    // MARK: Stream
    public typealias Output = HTTP.Client
    public var errorStream: ErrorHandler? {
        get { return tcp.errorStream }
        set { tcp.errorStream = newValue }
    }

    public var outputStream: OutputHandler?

    public let tcp: TCP.Server

    public init(tcp: TCP.Server) {
        self.tcp = tcp
        tcp.outputStream = { tcp in
            let client = HTTP.Client(tcp: tcp)
            self.outputStream?(client)
        }
    }
}
