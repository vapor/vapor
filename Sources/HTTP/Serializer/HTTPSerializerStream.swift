import Async
import Bits
import Foundation

/// Stream wrapper around an HTTP serializer.
public final class HTTPSerializerStream<Serializer>: Async.Stream where Serializer: HTTPSerializer {
    /// See InputStream.Input
    public typealias Input = Serializer.Message

    /// See OutputStream.Output
    public typealias Output = ByteBuffer

    /// Use a basic stream to easily implement our output stream.
    private let byteStream: ByteStream

    /// The underlying serializer
    private let serializer: Serializer

    /// Use this to request more messages from upstream.
    private var messageOutputRequest: OutputRequest?

    /// Amount of requested output remaining
    private var remainingByteBuffersRequested: UInt

    /// The serializer's state
    private var state: HTTPSerializerStreamState<Serializer.Message>

    /// A buffer used to store writes in temporarily
    private let writeBuffer: MutableByteBuffer

    /// Creates a new serializer stream. Use `HTTPSerializer.stream()` to call this method.
    internal init(serializer: Serializer, bufferSize: Int = 65_535) {
        self.serializer = serializer
        remainingByteBuffersRequested = 0
        state = .ready

        let pointer = MutableBytesPointer.allocate(capacity: bufferSize)
        writeBuffer = MutableByteBuffer(start: pointer, count: bufferSize)

        byteStream = .init()
        byteStream.onRequestClosure = onByteStreamRequest
        byteStream.onOutputClosure = onByteStreamOutput
    }

    /// Called when the byte stream requests more byte buffers
    private func onByteStreamRequest(count: UInt) {
        let isSuspended = remainingByteBuffersRequested == 0
        remainingByteBuffersRequested += count
        if isSuspended {
            update()
        }
    }

    /// Update based on state.
    private func update() {
        guard remainingByteBuffersRequested > 0 else {
            return
        }

        switch state {
        case .ready:
            // we are ready for a message, request it
            messageOutputRequest?.requestOutput()
        case .messageReady(let message):
            serializer.message = message
            state = .messageStreaming(message.body)
            update()
        case .messageStreaming(let body):
            /// continue streaming the message until
            /// the serializer indicates it is done
            let serialized = try! serializer.serialize(max: writeBuffer.count, into: writeBuffer)
            let frame = ByteBuffer(start: writeBuffer.baseAddress, count: serialized)
            byteStream.onInput(frame)
            remainingByteBuffersRequested -= 1

            /// the serializer indicates it is done w/ this message
            if serializer.message == nil {
                /// handle the body separately
                state = .bodyReady(body)
            }
            
            update()
        case .bodyReady(let body):
            switch body.storage {
            case .dispatchData(let data):
                Data(data).withByteBuffer(byteStream.onInput)
                remainingByteBuffersRequested -= 1
            case .data(let data):
                data.withByteBuffer(byteStream.onInput)
                remainingByteBuffersRequested -= 1
            case .staticString(let string):
                let buffer = UnsafeBufferPointer(start: string.utf8Start, count: string.utf8CodeUnitCount)
                byteStream.onInput(buffer)
                remainingByteBuffersRequested -= 1
            case .string(let string):
                let size = string.utf8.count
                string.withCString { pointer in
                    pointer.withMemoryRebound(to: UInt8.self, capacity: size) { pointer in
                        byteStream.onInput(ByteBuffer(start: pointer, count: size))
                        self.remainingByteBuffersRequested -= 1
                    }
                }
            case .stream(let bodyStream):
                /// we still have buffers requested, setup the stream
                let chunker = HTTPChunkEncodingStream()
                bodyStream.stream(to: chunker).stream(to: byteStream).finally {
                    self.state = .ready
                    self.update()
                }
            }
        case .bodyStreaming(let req):
            req.requestOutput(remainingByteBuffersRequested)
            remainingByteBuffersRequested = 0
        }
    }

    private func onByteStreamOutput(outputRequest: OutputRequest) {
        state = .bodyStreaming(outputRequest)
        update()
    }

    /// See InputStream.onOutput
    public func onOutput(_ outputRequest: OutputRequest) {
        remainingByteBuffersRequested = 0
        messageOutputRequest = outputRequest
    }

    /// See InputStream.onInput
    public func onInput(_ message: Input) {
        state = .messageReady(message)
        update()
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        byteStream.onError(error)
    }

    /// See OutputStream.onOutput
    public func output<I>(to input: I) where I: Async.InputStream, Output == I.Input {
        byteStream.output(to: input)
    }

    /// See InputStream.onClose
    public func onClose() {
        byteStream.onClose()
    }

    deinit {
        writeBuffer.baseAddress!.deinitialize()
        writeBuffer.baseAddress!.deallocate(capacity: writeBuffer.count)
    }
}

enum HTTPSerializerStreamState<Message> {
    case ready
    case messageReady(Message)
    case messageStreaming(HTTPBody)
    case bodyReady(HTTPBody)
    case bodyStreaming(OutputRequest)
}
