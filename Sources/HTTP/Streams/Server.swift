import Async
import TCP

/// HTTP server wrapped around TCP server
public final class HTTPServer: Async.OutputStream, ClosableStream {
    /// See OutputStream.Output
    public typealias Output = HTTPPeer

    /// The wrapped Client Stream
    private let socket: ClosableStream

    /// Use a basic stream to easily implement our output stream.
    private var outputStream: BasicStream<Output> = .init()

    /// Creates a new HTTP Server from a Client stream
    public init<TCPClientStream>(socket: TCPClientStream)
        where TCPClientStream: OutputStream,
        TCPClientStream.Output == TCPClient,
        TCPClientStream: ClosableStream
    {
        self.socket = socket
        let map = MapStream<TCPClient, HTTPPeer>(map: HTTPPeer.init)
        socket.stream(to: map).stream(to: outputStream)
    }

    /// See OutputStream.onOutput
    public func onOutput<I>(_ input: I) where I: InputStream, Output == I.Input {
        outputStream.onOutput(input)
    }

    /// See ClosableStream.onClose
    public func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
    }

    /// See ClosableStream.close
    public func close() {
        socket.close()
        outputStream.close()
    }
}
