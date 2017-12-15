import Async
import Bits
import Dispatch

/// A dispatch source compatible socket.
public protocol DispatchSocket {
    /// The file descriptor.
    var descriptor: Int32 { get }

    /// Reads a maxiumum of `max` bytes into the supplied mutable buffer.
    /// Returns the actual number of bytes read.
    func read(max: Int, into buffer: UnsafeMutableBufferPointer<UInt8>) throws -> Int

    /// Writes a maximum of `max` bytes from the supplied buffer.
    /// Returns the actual number of bytes written.
    func write(max: Int, from buffer: UnsafeBufferPointer<UInt8>) throws -> Int

    /// Closes the socket.
    func close()

    /// True if the socket is ready for normal use
    var isPrepared: Bool { get }

    /// Prepares the socket, called if isPrepared is false.
    func prepareSocket() throws
}

extension DispatchSocket {
    /// See DispatchSocket.isPrepared
    public var isPrepared: Bool { return true }

    /// See DispatchSocket.prepareSocket
    public func prepareSocket() throws {}
}

/// Data stream wrapper for a dispatch socket.
public final class DispatchSocketStream<Socket>: Stream, ConnectionContext
    where Socket: DispatchSocket
{
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
    private var downstream: AnyInputStream<ByteBuffer>?

    /// The current request controlling incoming write data
    private var upstream: ConnectionContext?

    /// The amount of requested output remaining
    private var requestedOutputRemaining: UInt

    internal init(socket: Socket, on eventLoop: EventLoop) {
        self.socket = socket
        self.eventLoop = eventLoop
        // Allocate one TCP packet
        let size = 65_507
        self.outputBuffer = MutableByteBuffer(start: .allocate(capacity: size), count: size)
        self.inputBuffer = nil
        self.requestedOutputRemaining = 0
    }

    /// See InputStream.input
    public func input(_ event: InputEvent<ByteBuffer>) {
        switch event {
        case .next(let input):
            /// crash if the upstream is illegally overproducing data
            guard inputBuffer == nil else {
                fatalError("\(#function) was called while inputBuffer is not nil")
            }

            inputBuffer = input
            resumeWriting()
        case .connect(let connection):
            upstream = connection
            connection.request()
        case .close:
            /// don't propogate to downstream or we will have an infinite loop
            close()
        case .error(let e): downstream?.error(e)
        }
    }

    /// See OutputStream.output
    public func output<S>(to inputStream: S) where S: Async.InputStream, S.Input == ByteBuffer {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }

    /// See ConnectionContext.connection
    public func connection(_ event: ConnectionEvent) {
        switch event {
        case .request(let count):
            /// We must add checks to this method since it is
            /// called everytime downstream requests more data.
            /// Not checking counts would result in over resuming
            /// the dispatch source.
            let isSuspended = requestedOutputRemaining == 0
            requestedOutputRemaining += count

            /// ensure was suspended and output has actually
            /// been requested
            if isSuspended && requestedOutputRemaining > 0 {
                ensureReadSource().resume()
            }
        case .cancel: close()
        }
    }

    /// Cancels reading
    public func close() {
        socket.close()
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
        guard socket.isPrepared else {
            do {
                try socket.prepareSocket()
            } catch {
                downstream?.error(error)
            }
            return
        }

        let read: Int
        do {
            read = try socket.read(
                max: outputBuffer.count,
                into: outputBuffer
            )
        } catch {
            // any errors that occur here cannot be thrown,
            //selfso send them to stream error catcher.
            downstream?.error(error)
            return
        }

        guard read > 0 else {
            close() // used to be source.cancel
            return
        }

        // create a view into our internal buffer and
        // send to the output stream
        let bufferView = ByteBuffer(
            start: outputBuffer.baseAddress,
            count: read
        )
        downstream?.next(bufferView)

        /// decrement remaining and check if
        /// we need to suspend accepting
        self.requestedOutputRemaining -= 1
        if self.requestedOutputRemaining == 0 {
            suspendReading()
        }
    }

    /// Writes the buffered data to the socket.
    private func writeData() {
        guard socket.isPrepared else {
            do {
                try socket.prepareSocket()
            } catch {
                downstream?.error(error)
            }
            return
        }

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
                upstream?.request()
            default: print("not all data was written: \(count)/\(input.count)")
            }
        } catch {
            downstream?.error(error)
        }
    }

    /// Returns the existing read source or creates
    /// and stores a new one
    private func ensureReadSource() -> DispatchSourceRead {
        guard let existing = readSource else {
            /// create a new read source
            let source = DispatchSource.makeReadSource(
                fileDescriptor: socket.descriptor,
                queue: eventLoop.queue
            )

            /// handle socket ready to read
            source.setEventHandler(handler: readData)

            /// handle a cancel event
            source.setCancelHandler(handler: close)

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
                fileDescriptor: socket.descriptor,
                queue: eventLoop.queue
            )

            /// handle socket ready to write
            source.setEventHandler(handler: writeData)

            /// handle a cancel event
            source.setCancelHandler(handler: close)

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
