import Async

/// Stream representation of a TCP server.
public final class TCPClientStream: OutputStream, ConnectionContext {
    /// See OutputStream.Output
    public typealias Output = TCPClient

    /// The server being streamed
    public var server: TCPServer

    /// This stream's event loop
    public let eventLoop: EventLoop

    /// Downstream client and eventloop input stream
    private var downstream: AnyInputStream<Output>?

    /// The amount of requested output remaining
    private var requestedOutputRemaining: UInt

    /// Keep a reference to the read source so it doesn't deallocate
    private var acceptSource: EventSource?

    /// Use TCPServer.stream to create
    internal init(server: TCPServer, on eventLoop: EventLoop) {
        self.eventLoop = eventLoop
        self.server = server
        self.requestedOutputRemaining = 0
    }

    /// See OutputStream.output
    public func output<S>(to inputStream: S) where S: InputStream, S.Input == Output {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }

    /// See ConnectionContext.connection
    public func connection(_ event: ConnectionEvent) {
        switch event {
        case.request(let count):
            /// handle downstream requesting data
            /// suspend will be called automatically if the
            /// remaining requested output count ever
            /// reaches zero.
            /// the downstream is expected to continue
            /// requesting additional output as it is ready.
            /// the server will automatically resume if
            /// additional clients are requested after
            /// suspend has been called
            self.request(count)
        case .cancel:
            /// handle downstream canceling output requests
            self.cancel()
        }
    }

    /// Resumes accepting clients if currently suspended
    /// and count is greater than 0
    private func request(_ accepting: UInt) {
        let isSuspended = requestedOutputRemaining == 0
        if accepting == .max {
            requestedOutputRemaining = .max
        } else {
            requestedOutputRemaining += accepting
        }

        if isSuspended && requestedOutputRemaining > 0 {
            ensureAcceptSource().resume()
        }
    }

    /// Cancels the stream
    private func cancel() {
        server.stop()
        downstream?.close()
        if requestedOutputRemaining == 0 {
            /// dispatch sources must be resumed before
            /// deinitializing
            acceptSource?.resume()
        }
        acceptSource = nil
    }

    /// Accepts a client and outputs to the stream
    private func accept(isCancelled: Bool) {
        do {
            guard let client = try server.accept() else {
                // the client was rejected
                return
            }

            //            let eventLoop = eventLoopsIterator.next()

            downstream?.next(client)

            /// decrement remaining and check if
            /// we need to suspend accepting
            if requestedOutputRemaining != .max {
                requestedOutputRemaining -= 1
                if requestedOutputRemaining == 0 {
                    ensureAcceptSource().suspend()
                    requestedOutputRemaining = 0
                }
            }
        } catch {
            downstream?.error(error)
        }
    }

    /// Returns the existing accept source or creates
    /// and stores a new one
    private func ensureAcceptSource() -> EventSource {
        guard let existing = acceptSource else {
            /// create a new accept source
            let source = self.eventLoop.onReadable(descriptor: server.socket.descriptor, accept)
            acceptSource = source
            return source
        }

        /// return the existing source
        return existing
    }
}
