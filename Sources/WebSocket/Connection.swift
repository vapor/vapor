import Bits
import Async
import Dispatch
import HTTP
import TCP

/// Manages frames to and from a TCP connection
internal final class Connection: Async.Stream, ClosableStream {
    /// See InputStream.Input
    typealias Input = Frame
    
    /// See OutputStream.Output
    typealias Output = Frame
    
    /// Serializes data into frames
    let serializer: FrameSerializer
    
    /// Defines the side of the socket
    ///
    /// Server side Sockets don't use masking
    let serverSide: Bool

    /// The underlying TCP connection
    let socket: ClosableStream

    /// Use a basic stream to easily implement our output stream.
    private var outputStream: BasicStream<Output> = .init()
    
    /// Creates a new WebSocket Connection manager for a TCP.Client
    ///
    /// `serverSide` is used to determine if sent frames need to be masked
    init<ByteStream>(socket: ByteStream, serverSide: Bool = true) where
        ByteStream: Async.Stream,
        ByteStream.Input == ByteBuffer,
        ByteStream.Output == ByteBuffer
    {
        self.socket = socket
        self.serverSide = serverSide
        
        let parser = FrameParser()
        serializer = FrameSerializer(masking: !serverSide)
        
        // Streams incoming data into the parser which sends it to this frame's handler
        socket.stream(to: parser).stream(to: outputStream)
        // Streams outgoing data to the serializer, which sends it over the socket
        serializer.stream(to: socket)
    }

    /// See OutputStream.onInput
    func onInput(_ input: Frame) {
        serializer.onInput(input)
    }

    /// See OutputStream.onError
    func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    func onOutput<I>(_ input: I) where I : InputStream, Connection.Output == I.Input {
        outputStream.onOutput(input)
    }

    /// See ClosableStream.onClose
    func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
    }

    /// Sends the closing frame and closes the connection
    func close() {
        do {
            let frame = try Frame(
                op: .close,
                payload: ByteBuffer(start: nil, count: 0),
                mask: serverSide ? nil : randomMask(),
                isFinal: true
            )
            self.onInput(frame)
            self.socket.close()
            outputStream.close()
        } catch {
            onError(error)
        }
    }
}
