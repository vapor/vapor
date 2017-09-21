import Core
import TCP

/// HTTP server wrapped around TCP server
public final class Server<S: OutputStream>: Core.OutputStream where S.Output == TCP.Client {
    // MARK: Stream
    public typealias Output = HTTP.Client
    public var errorStream: ErrorHandler? {
        get { return server.errorStream }
        set { server.errorStream = newValue }
    }

    public var outputStream: OutputHandler?

    public let server: S

    public init(server: S) {
        self.server = server
        server.outputStream = { tcp in
            let client = HTTP.Client(tcp: tcp)
            self.outputStream?(client)
        }
    }
}
