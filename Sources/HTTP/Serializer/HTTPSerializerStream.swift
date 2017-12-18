import Async
import Bits
import Foundation
import TCP

/// Stream wrapper around an HTTP serializer.
public final class HTTPSerializerStream<Serializer>: Async.Stream, ConnectionContext
    where Serializer: HTTPSerializer
{
    /// See InputStream.Input
    public typealias Input = Serializer.Message

    /// See OutputStream.Output
    public typealias Output = ByteBuffer

    /// The underlying serializer
    private let serializer: Serializer

    /// Use this to request more messages from upstream.
    private var upstream: ConnectionContext?

    /// Amount of requested output remaining
    private var remainingByteBuffersRequested: UInt

    /// The serializer's state
    private var state: HTTPSerializerStreamState<Serializer.Message>

    /// A buffer used to store writes in temporarily
    private let writeBuffer: MutableByteBuffer

    /// Downstream byte buffer input stream
    private var downstream: AnyInputStream<Output>?

    /// Creates a new serializer stream. Use `HTTPSerializer.stream()` to call this method.
    internal init(serializer: Serializer, bufferSize: Int) {
        self.serializer = serializer
        remainingByteBuffersRequested = 0
        state = .ready
        let pointer = MutableBytesPointer.allocate(capacity: bufferSize)
        writeBuffer = MutableByteBuffer(start: pointer, count: bufferSize)
    }

    /// See ConnectionContext.connection
    public func connection(_ event: ConnectionEvent) {
        switch event {
        case .request(let count):
            let isSuspended = remainingByteBuffersRequested == 0
            remainingByteBuffersRequested += count
            if isSuspended { update() }
        case .cancel:
            /// FIXME: cancel
            break
        }
    }

    /// See InputStream.input
    public func input(_ event: InputEvent<Serializer.Message>) {
        switch event {
        case .close:
            downstream?.close()
        case .connect(let upstream):
            remainingByteBuffersRequested = 0
            self.upstream = upstream
        case .error(let error):
            downstream?.error(error)
        case .next(let input):
            state = .messageReady(input)
            update()
        }
    }

    /// See OutputStream.onOutput
    public func output<I>(to inputStream: I) where I: Async.InputStream, Output == I.Input {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }


    /// Update based on state.
    private func update() {
        guard remainingByteBuffersRequested > 0 else {
            return
        }

        switch state {
        case .ready:
            // we are ready for a message, request it
            upstream?.request()
            state = .awaitingMessage
        case .awaitingMessage: break
        case .messageReady(let message):
            serializer.setMessage(to: message)
            state = .messageStreaming(message.body)
            update()
        case .messageStreaming(let body):
            /// continue streaming the message until
            /// the serializer indicates it is done
            let serialized = try! serializer.serialize(into: writeBuffer)
            let frame = ByteBuffer(start: writeBuffer.baseAddress, count: serialized)
            downstream?.next(frame)
            remainingByteBuffersRequested -= 1

            /// the serializer indicates it is done w/ this message
            if serializer.ready {
                /// handle the body separately
                state = .bodyReady(body)
            }
            update()
        case .bodyReady(let body):
            switch body.storage {
            case .dispatchData(let data):
                Data(data).withByteBuffer(downstream!.next)
                remainingByteBuffersRequested -= 1
                state = .ready
                update()
            case .data(let data):
                data.withByteBuffer(downstream!.next)
                remainingByteBuffersRequested -= 1
                state = .ready
                update()
            case .staticString(let string):
                let buffer = UnsafeBufferPointer(start: string.utf8Start, count: string.utf8CodeUnitCount)
                downstream!.next(buffer)
                remainingByteBuffersRequested -= 1
                state = .ready
                update()
            case .string(let string):
                let size = string.utf8.count
                string.withCString { pointer in
                    pointer.withMemoryRebound(to: UInt8.self, capacity: size) { pointer in
                        self.downstream!.next(ByteBuffer(start: pointer, count: size))
                        self.remainingByteBuffersRequested -= 1
                    }
                }
                state = .ready
                update()
            case .outputStream(let closure):
                closure(HTTPChunkEncodingStream()).drain { req in
                    self.state = .bodyStreaming(req)
                    self.update()
                }.output { buffer in
                    self.remainingByteBuffersRequested -= 1
                    self.downstream!.next(buffer)
                    self.update()
                }.catch { error in
                    self.downstream?.error(error)
                }.finally {
                    self.state = .ready
                    self.update()
                }
            }
        case .bodyStreaming(let req):
            req.request()
        }
    }

    deinit {
        writeBuffer.baseAddress!.deinitialize(count: writeBuffer.count)
        writeBuffer.baseAddress!.deallocate(capacity: writeBuffer.count)
    }
}

enum HTTPSerializerStreamState<Message> {
    case ready
    case awaitingMessage
    case messageReady(Message)
    case messageStreaming(HTTPBody)
    case bodyReady(HTTPBody)
    case bodyStreaming(ConnectionContext)
}

extension HTTPSerializer {
    /// Create a stream for this serializer.
    public func stream(bufferSize: Int = .maxTCPPacketSize) -> HTTPSerializerStream<Self> {
        return HTTPSerializerStream(serializer: self, bufferSize: bufferSize)
    }
}
