import Async
import Bits
import Dispatch

/// A dispatch source compatible socket.
public protocol DispatchSocket {
    /// The file descriptor.
    var fileDescriptor: Int32 { get }

    /// Reads a maxiumum of `max` bytes into the supplied mutable buffer.
    /// Returns the actual number of bytes read.
    func read(max: Int, into buffer: UnsafeMutableBufferPointer<UInt8>) throws -> Int

    /// Writes a maximum of `max` bytes from the supplied buffer.
    /// Returns the actual number of bytes written.
    func write(max: Int, from buffer: UnsafeBufferPointer<UInt8>) throws -> Int

    /// Closes the socket.
    func close()
}

/// Data stream wrapper for a dispatch socket.
public final class DispatchSocketStream<Socket>: Stream where Socket: DispatchSocket {
    /// See InputStream.Input
    public typealias Input = ByteBuffer

    /// See OutputStream.Output
    public typealias Output = ByteBuffer

    /// The client stream's underlying socket.
    public var socket: Socket

    /// This stream's event loop
    public let eventLoop: EventLoop

    /// Bytes from the socket are read into this buffer.
    /// Views into this buffer supplied to output streams.
    private let outputBuffer: MutableByteBuffer

    /// Data being fed into the client stream is stored here.
    private var inputBuffer: ByteBuffer?

    /// Stores read event source.
    private var readSource: DispatchSourceRead?

    /// Stores write event source.
    private var writeSource: DispatchSourceWrite?

    /// Use a basic stream to easily implement our output stream.
    private var outputStream: BasicStream<Output>

    /// The amount of requested output remaining
    private var requestedOutputRemaining: UInt

    /// The current request controlling incoming write data
    private var outputRequest: OutputRequest?

    internal init(socket: Socket, on eventLoop: EventLoop) {
        self.socket = socket
        self.eventLoop = eventLoop
        // Allocate one TCP packet
        let size = 65_507
        self.outputBuffer = MutableByteBuffer(start: .allocate(capacity: size), count: size)
        self.inputBuffer = nil
        self.requestedOutputRemaining = 0
        self.outputRequest = nil
        self.outputStream = .init()

        /// handle downstream requesting data
        self.outputStream.onRequestClosure = request

        /// handle downstream canceling output requests
        self.outputStream.onCancelClosure = cancel
    }

    /// See InputStream.onInput
    public func onInput(_ input: ByteBuffer) {
        /// detect if the upstream is overproducing data
        guard inputBuffer == nil else {
            fatalError("\(#function) was called while inputBuffer is not nil")
        }

        inputBuffer = input
        resumeWriting()
    }

    /// See InputStream.onOutput
    public func onOutput(_ outputRequest: OutputRequest) {
        self.outputRequest = outputRequest
        outputRequest.requestOutput()
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See InputStream.onClose
    public func onClose() {
        outputStream.onClose()
    }

    /// See OutputStream.output
    public func output<S>(to inputStream: S) where S: Async.InputStream, S.Input == ByteBuffer {
        outputStream.output(to: inputStream)
    }

    /// Resumes reading data.
    private func request(_ reading: UInt) {
        /// We must add checks to this method since it is
        /// called everytime downstream requests more data.
        /// Not checking counts would result in over resuming
        /// the dispatch source.
        let isSuspended = requestedOutputRemaining == 0
        requestedOutputRemaining += reading

        /// ensure was suspended and output has actually
        /// been requested
        if isSuspended && requestedOutputRemaining > 0 {
            ensureReadSource().resume()
        }
    }

    /// Cancels reading
    private func cancel() {
        socket.close()
        onClose()
        if requestedOutputRemaining == 0 {
            /// dispatch sources must be resumed before
            /// deinitializing
            readSource?.resume()
        }
        readSource = nil
        if inputBuffer == nil {
            /// dispatch sources must be resumed before
            /// deinitializing
            writeSource?.resume()
        }
        writeSource = nil
    }

    /// Suspends reading data.
    private func suspendReading() {
        ensureReadSource().suspend()
        /// must be zero or resume will fail
        requestedOutputRemaining = 0
    }

    /// Resumes writing data
    private func resumeWriting() {
        ensureWriteSource().resume()
    }

    /// Suspends writing data
    private func suspendWriting() {
        ensureWriteSource().suspend()
    }

    /// Reads data and outputs to the output stream
    /// important: the socket _must_ be ready to read data
    /// as indicated by a read source.
    private func readData() {
        print("socket ready to read")
        let read: Int
        do {
            read = try socket.read(
                max: outputBuffer.count,
                into: outputBuffer
            )
        } catch {
            // any errors that occur here cannot be thrown,
            //selfso send them to stream error catcher.
            outputStream.onError(error)
            return
        }

        guard read > 0 else {
            cancel() // used to be source.cancel
            return
        }

        // create a view into our internal buffer and
        // send to the output stream
        let bufferView = ByteBuffer(
            start: outputBuffer.baseAddress,
            count: read
        )
        outputStream.onInput(bufferView)

        /// decrement remaining and check if
        /// we need to suspend accepting
        self.requestedOutputRemaining -= 1
        if self.requestedOutputRemaining == 0 {
            suspendReading()
        }
    }

    /// Writes the buffered data to the socket.
    private func writeData() {
        print("socket ready to write")
        guard let input = inputBuffer else {
            fatalError("\(#function) called while inputBuffer is nil")
        }

        do {
            let count = try socket.write(max: input.count, from: input)
            switch count {
            case input.count:
                // wrote everything, suspend until we get more data to write
                inputBuffer = nil
                suspendWriting()
                outputRequest?.requestOutput()
            case 0:
                // wrote nothing, don't suspend so write gets
                // called again
                break
            default: print("not all data was written: \(count)/\(input.count)")
            }
        } catch {
            onError(error)
        }
    }

    /// Returns the existing read source or creates
    /// and stores a new one
    private func ensureReadSource() -> DispatchSourceRead {
        guard let existing = readSource else {
            /// create a new read source
            let source = DispatchSource.makeReadSource(
                fileDescriptor: socket.fileDescriptor,
                queue: eventLoop.queue
            )

            /// handle socket ready to read
            source.setEventHandler(handler: readData)

            /// handle a cancel event
            source.setCancelHandler(handler: cancel)

            readSource = source
            return source
        }

        return existing
    }

    /// Creates a new WriteSource if there is no write source yet
    private func ensureWriteSource() -> DispatchSourceWrite {
        guard let source = writeSource else {
            /// create a new write source
            let source = DispatchSource.makeWriteSource(
                fileDescriptor: socket.fileDescriptor,
                queue: eventLoop.queue
            )

            /// handle socket ready to write
            source.setEventHandler(handler: writeData)

            /// handle a cancel event
            source.setCancelHandler(handler: cancel)

            writeSource = source
            return source
        }

        return source
    }

    /// Disables the read source so that another read source (such as for SSL) can take over
    public func disableReadSource() {
        self.readSource?.cancel()
        self.readSource?.suspend()
    }

    /// Deallocated the pointer buffer
    deinit {
        outputBuffer.baseAddress.unsafelyUnwrapped.deallocate(capacity: outputBuffer.count)
        outputBuffer.baseAddress.unsafelyUnwrapped.deinitialize()
    }
}

/// MARK: Create

extension DispatchSocket {
    /// Creates a data stream for this socket on the supplied event loop.
    public func stream(on eventLoop: EventLoop) -> DispatchSocketStream<Self> {
        return DispatchSocketStream(socket: self, on: eventLoop)
    }
}
