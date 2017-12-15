import Async
import Bits
import Foundation
import TCP

/// Stream wrapper around an HTTP serializer.
public final class HTTPSerializerStream<Serializer>: Async.Stream, OutputRequest
    where Serializer: HTTPSerializer
{
    /// See InputStream.Input
    public typealias Input = Serializer.Message

    /// See OutputStream.Output
    public typealias Output = ByteBuffer

    /// The underlying serializer
    private let serializer: Serializer

    /// Use this to request more messages from upstream.
    private var messageOutputRequest: OutputRequest?

    /// Amount of requested output remaining
    private var remainingByteBuffersRequested: UInt {
        didSet { print("remainingByteBuffersRequested: \(remainingByteBuffersRequested)") }
    }

    /// The serializer's state
    private var state: HTTPSerializerStreamState<Serializer.Message>

    /// A buffer used to store writes in temporarily
    private let writeBuffer: MutableByteBuffer

    /// Downstream byte buffer input stream
    private var downstream: AnyInputStream!

    /// Creates a new serializer stream. Use `HTTPSerializer.stream()` to call this method.
    internal init(serializer: Serializer, bufferSize: Int) {
        self.serializer = serializer
        remainingByteBuffersRequested = 0
        state = .ready
        let pointer = MutableBytesPointer.allocate(capacity: bufferSize)
        writeBuffer = MutableByteBuffer(start: pointer, count: bufferSize)
    }

    /// Called when the byte stream requests more byte buffers
    public func requestOutput(_ count: UInt) {
        let isSuspended = remainingByteBuffersRequested == 0
        remainingByteBuffersRequested += count
        if isSuspended { update() }
    }

    /// Called when downstream cancels output from this stream
    public func cancelOutput() {
        /// FIXME: cancel
    }

    /// Update based on state.
    private func update() {
        guard remainingByteBuffersRequested > 0 else {
            return
        }
        print(state)

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
            print(serialized)
            let frame = ByteBuffer(start: writeBuffer.baseAddress, count: serialized)
            downstream.unsafeOnInput(frame)
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
                Data(data).withByteBuffer(downstream.unsafeOnInput)
                remainingByteBuffersRequested -= 1
                state = .ready
                update()
            case .data(let data):
                data.withByteBuffer(downstream.unsafeOnInput)
                remainingByteBuffersRequested -= 1
                state = .ready
                update()
            case .staticString(let string):
                let buffer = UnsafeBufferPointer(start: string.utf8Start, count: string.utf8CodeUnitCount)
                downstream.unsafeOnInput(buffer)
                remainingByteBuffersRequested -= 1
                state = .ready
                update()
            case .string(let string):
                let size = string.utf8.count
                string.withCString { pointer in
                    pointer.withMemoryRebound(to: UInt8.self, capacity: size) { pointer in
                        self.downstream.unsafeOnInput(ByteBuffer(start: pointer, count: size))
                        self.remainingByteBuffersRequested -= 1
                    }
                }
                state = .ready
                update()
            case .outputStream(let closure):
                self.remainingByteBuffersRequested -= 1
                closure(HTTPChunkEncodingStream()).drain { req in
                    self.state = .bodyStreaming(req)
                    req.requestOutput(1)
                }.output { buffer in
                    self.downstream.unsafeOnInput(buffer)
                    self.update()
                }.catch { error in
                    self.onError(error)
                }.finally {
                    self.state = .ready
                    self.update()
                }
            }
        case .bodyStreaming(let req):
            req.requestOutput(remainingByteBuffersRequested)
            remainingByteBuffersRequested = 0
        }
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
        downstream.onError(error)
    }

    /// See OutputStream.onOutput
    public func output<I>(to inputStream: I) where I: Async.InputStream, Output == I.Input {
        downstream = inputStream
        inputStream.onOutput(self)
    }

    /// See InputStream.onClose
    public func onClose() {
       downstream.onClose()
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

extension HTTPSerializer {
    /// Create a stream for this serializer.
    public func stream(bufferSize: Int = .maxTCPPacketSize) -> HTTPSerializerStream<Self> {
        return HTTPSerializerStream(serializer: self, bufferSize: bufferSize)
    }
}
