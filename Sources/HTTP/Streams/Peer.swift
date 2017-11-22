import Async
import Bits
import TCP
import Foundation

/// An HTTP `Server`'s peer wrapped around TCP client
public final class HTTPPeer: Async.Stream, ClosableStream {
    /// See InputStream.Input
    public typealias Input = Data
    
    /// See OutputStream.Output
    public typealias Output = ByteBuffer

    // See CloseableStream.onClose
    public var onClose: OnClose?

    /// The underlying TCP Client
    public let tcp: TCPClient

    /// Use a basic stream to easily implement our output stream.
    private let outputStream: BasicStream<Output>

    /// Creates a new `Peer` from a `TCP.Client`
    public init(tcp: TCPClient) {
        self.tcp = tcp
        self.outputStream = .init()
        tcp.stream(to: outputStream)
    }

    /// See InputStream.onInput
    public func onInput(_ input: Data) {
        tcp.inputStream(input)
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    public func onOutput<I>(_ input: I) where I: Async.InputStream, Output == I.Input {
        outputStream.onOutput(input)
    }

    /// See Closable.close
    public func close() {
        tcp.close()
    }
}
