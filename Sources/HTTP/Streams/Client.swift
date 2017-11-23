import Async
import Bits
import Foundation
import TCP

/// An HTTP client wrapped around TCP client
///
/// Can handle a single `Request` at a given time.
///
/// Multiple requests at the same time are subject to unknown behaviour
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/client/)
public final class HTTPClient: Async.Stream, ClosableStream {
    /// See InputStream.Input
    public typealias Input = Request

    /// See OutputStream.Output
    public typealias Output = Response

    /// Parses the received `Response`s
    private let parser: ResponseParser

    /// Serializes the inputted `Request`s
    private let serializer: RequestSerializer

    /// Use a basic stream to easily implement our output stream.
    private let outputStream: BasicStream<Output>

    /// The client's current in flight promise
    private var inFlight: Promise<Response>?

    /// The socket from init. We need to hold
    /// onto it to close when the client closes.
    private var socket: ClosableStream
    
    /// Creates a new Client wrapped around a `TCP.Client`
    public init<ByteStream>(socket: ByteStream, maxBodySize: Int = 10_000_000)
        where ByteStream: Async.Stream,
            ByteStream.Input == ByteBuffer,
            ByteStream.Output == ByteBuffer
    {
        self.parser = ResponseParser(maxBodySize: maxBodySize)
        self.serializer = RequestSerializer()
        self.outputStream = .init()
        self.socket = socket

        let dataToByteByffer = MapStream<Data, ByteBuffer> { data in
            return data.withByteBuffer { $0 }
        }

        /// FIXME: is there a way to support end users
        /// setting an output stream as well?
        outputStream.drain { res in
            if let inFlight = self.inFlight {
                inFlight.complete(res)
                self.inFlight = nil
            }
        }.catch { err in
            if let inFlight = self.inFlight {
                inFlight.fail(err)
                self.inFlight = nil
            }
        }

        serializer.stream(to: dataToByteByffer).stream(to: socket)
        socket.stream(to: parser).stream(to: outputStream)
    }
    
    /// Sends a single `Request` and returns a future that can be completed with a `Response`.
    public func send(request: RequestEncodable) -> Future<Response> {
        if let inFlight = self.inFlight {
            /// complete the current in flight request
            /// before sending the next one
            return inFlight.future.then { _ in
                return self._send(request: request)
            }
        } else {
            return _send(request: request)
        }
    }

    /// Sends a request, not regarding any inflight requests.
    private func _send(request: RequestEncodable) -> Future<Response> {
        return then {
            var req = Request()
            return try request.encode(to: &req).then { _ -> Future<Response> in
                let promise = Promise(Response.self)
                self.inFlight = promise
                self.serializer.onInput(req)
                return promise.future
            }
        }
    }

    /// See InputStream.onInput
    public func onInput(_ input: Request) {
        serializer.onInput(input)
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See InputStream.onOutput
    public func onOutput<I>(_ input: I) where I: Async.InputStream, Output == I.Input {
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
