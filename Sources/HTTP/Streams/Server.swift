import Async
import TCP

/// HTTP server wrapped around TCP server
public final class Server<OS: OutputStream>: Async.OutputStream where OS.Output == TCP.Client {
    // MARK: Stream
    public typealias Output = HTTP.Peer
    public var errorStream: ErrorHandler? {
        get { return tcp.errorStream }
        set { tcp.errorStream = newValue }
    }

    public var outputStream: OutputHandler?

    public let tcp: OS

    public init(tcp: OS) {
        self.tcp = tcp
        tcp.outputStream = { tcp in
            let client = HTTP.Peer(tcp: tcp)
            self.outputStream?(client)
        }
    }
}
