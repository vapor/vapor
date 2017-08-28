import Core
import TCP

/// An HTTP client wrapped around TCP client
public final class Client: Core.Stream {
    public typealias Input = SerializedMessage
    public typealias Output = ByteBuffer

    public var outputStream: OutputHandler? {
        get {
            return tcp.outputStream
        }
        set {
            tcp.outputStream = newValue
        }
    }
    public var errorStream: ErrorHandler?

    public let tcp: TCP.Client

    public init(tcp: TCP.Client) {
        self.tcp = tcp
    }

    public func inputStream(_ input: SerializedMessage) {
        tcp.inputStream(input.message)
        input.onUpgrade?(tcp)
    }
}
