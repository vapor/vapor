import Async
import Bits
import TCP

internal final class HTTPServerStream<AcceptStream, ByteStream>: Stream
    where AcceptStream: OutputStream,
        AcceptStream.Output == ByteStream,
        ByteStream: Stream,
        ByteStream.Input == ByteBuffer,
        ByteStream.Output == ByteBuffer,
        ByteStream: HTTPUpgradable
{
    /// See InputStream.Input
    typealias Input = ByteStream

    /// See OutputStream.Output
    typealias Output = HTTPClientStream<ByteStream>

    private var acceptStream: AcceptStream

    private var upstream: ConnectionContext?

    private var downstream: AnyInputStream<Output>?

    init(acceptStream: AcceptStream) {
        self.acceptStream = acceptStream
        acceptStream.output(to: self)
    }

    func output<S>(to inputStream: S) where S : InputStream, S.Input == Output {
        downstream = AnyInputStream(wrapped: inputStream)
        if let upstream = upstream {
            downstream?.connect(to: upstream)
        }
    }

    func input(_ event: InputEvent<ByteStream>) {
        switch event {
        case .connect(let upstream):
            self.downstream?.connect(to: upstream)
        case .next(let byteStream):
            let clientStream = HTTPClientStream(byteStream: byteStream)
            downstream?.next(clientStream)
        case .error(let error): downstream?.error(error)
        case .close: downstream?.close()
        }
    }
}

public final class HTTPServer<AcceptStream, ByteStream>
    where AcceptStream: OutputStream,
        AcceptStream.Output == ByteStream,
        ByteStream: Stream,
        ByteStream.Input == ByteBuffer,
        ByteStream.Output == ByteBuffer,
        ByteStream: HTTPUpgradable
{

    private let serverStream: HTTPServerStream<AcceptStream, ByteStream>

    public init(acceptStream: AcceptStream) {
        self.serverStream = HTTPServerStream<AcceptStream, ByteStream>(acceptStream: acceptStream)
    }

    public func start<Responder>(using responder: @escaping () -> (Responder))
        where Responder: Async.Stream,
            Responder.Input == HTTPRequest,
            Responder.Output == HTTPResponse
    {
        serverStream.drain { connection in
            /// never stop accepting
            connection.request(count: .max)
        }.output { clientStream in
            let responderStream = responder()
            clientStream.stream(to: responderStream).output(to: clientStream)
        }.catch { error in
            print(error)
        }.finally {
            print("closed")
        }
    }
}
