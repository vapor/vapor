import Async
import Bits
import Async
import Dispatch
import Foundation
import COperatingSystem
import Service

/// Read and write byte buffers from a TCPClient.
///
/// These are usually created as output by a TCPServer.
///
/// [Learn More →](https://docs.vapor.codes/3.0/sockets/tcp-client/)
public final class TCPClient: Async.Stream {
    /// See InputStream.Input
    public typealias Input = ByteBuffer

    /// See OutputStream.Output
    public typealias Output = ByteBuffer

    /// This client's dispatch queue. Use this
    /// for all async operations performed as a
    /// result of this client.
    public let eventLoop: EventLoop

    /// The client stream's underlying socket.
    private var socket: TCPSocket

    /// Handles close events
    public typealias WillClose = () -> ()
    
    /// Will be triggered before closing the socket, as part of the cleanup process
    public var willClose: WillClose?

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
    private var outputStream: BasicStream<Output>?

    /// The amount of requested output remaining
    private var requestedOutputRemaining: UInt

    /// The current request controlling incoming write data
    private var outputRequest: OutputRequest?

    /// Creates a new TCPClient from an existing TCPSocket.
    public init(socket: TCPSocket, on eventLoop: EventLoop) {
        self.socket = socket
        self.eventLoop = eventLoop

        // Allocate one TCP packet
        let size = 65_507
        self.outputBuffer = MutableByteBuffer(start: .allocate(capacity: size), count: size)
        self.requestedOutputRemaining = 0
        self.inputBuffer = nil

        /// starts the client immediately upon init
        /// we may decide to remove this at some point for
        /// parity with the tcp server api
        start()
    }

    /// Creates a new TCPClient
    public convenience init(on eventLoop: EventLoop) throws {
        let socket = try TCPSocket()
        socket.disablePipeSignal()
        self.init(socket: socket, on: eventLoop)
    }

    /// Starts receiving data from the client
    public func start() {
        /// initialize the internal output stream
        let outputStream = BasicStream<ByteBuffer>()

        /// handle downstream requesting data
        outputStream.onRequestClosure = resumeReading

        /// handle downstream canceling output requests
        outputStream.onCancelClosure = stop

        self.outputStream = outputStream
    }

    /// Stops the client
    public func stop() {
        willClose?()
        socket.close()
        onClose()
        outputStream = nil
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

    /// Attempts to connect to a server on the provided hostname and port
    public func connect(hostname: String, port: UInt16) throws {
        try self.socket.connect(hostname: hostname, port: port)
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
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        outputStream?.onError(error)
    }

    /// See InputStream.onClose
    public func onClose() {
        outputStream?.onClose()
    }

    /// See OutputStream.output
    public func output<S>(to inputStream: S) where S: Async.InputStream, TCPClient.Output == S.Input {
        /// it should be impossible to call this function when the
        /// outputStream is nil. fatalError here may help catch bugs.
        guard let outputStream = self.outputStream else {
            fatalError("\(#function) called while outputStream is nil")
        }

        outputStream.output(to: inputStream)
    }

    /// Resumes reading data.
    private func resumeReading(_ reading: UInt) {
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
        /// it should be impossible to call this function when the
        /// outputStream is nil. fatalError here may help catch bugs.
        guard let outputStream = self.outputStream else {
            fatalError("\(#function) called while outputStream is nil")
        }

        let read: Int
        do {
            read = try socket.read(
                max: outputBuffer.count,
                into: outputBuffer.baseAddress!
            )
        } catch {
            // any errors that occur here cannot be thrown,
            //selfso send them to stream error catcher.
            outputStream.onError(error)
            return
        }

        guard read > 0 else {
            stop() // used to be source.cancel
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
        guard let input = inputBuffer else {
            fatalError("\(#function) called while inputBuffer is nil")
        }

        do {
            let count = try socket.write(from: input)
            if count == input.count {
                inputBuffer = nil
                suspendWriting()
                outputRequest?.requestOutput()
            } else {
                /// let data = Data(input[input.count...])
                /// FIXME:
                fatalError("not all data was written")
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
                fileDescriptor: socket.descriptor,
                queue: eventLoop.queue
            )

            /// handle socket ready to read
            source.setEventHandler(handler: readData)

            /// handle a cancel event
            source.setCancelHandler(handler: stop)

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
            source.setCancelHandler(handler: stop)

            writeSource = source
            return source
        }

        return source
    }

    /// Deallocated the pointer buffer
    deinit {
        stop()
        outputBuffer.baseAddress.unsafelyUnwrapped.deallocate(capacity: outputBuffer.count)
        outputBuffer.baseAddress.unsafelyUnwrapped.deinitialize()
    }
}
