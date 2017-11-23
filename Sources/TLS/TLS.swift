#if (os(macOS) || os(iOS)) && !OPENSSL
    import AppleSSL
#else
    import OpenSSL
#endif

import Async
import Bits
import Core
import Dispatch
import TCP

/// A Client (used for connecting to servers) that uses the platform specific SSL library.
public final class TLSClient: Async.Stream, ClosableStream {
    /// See OutputStream.Output
    public typealias Output = ByteBuffer
    
    /// See InputStream.Input
    public typealias Input = ByteBuffer
    
    /// The AppleSSL (macOS/iOS) or OpenSSL (Linux) stream
    let ssl: SSLStream
    
    /// The TCP that is used in the SSL Stream
    let client: TCPClient
    
    /// A DispatchQueue on which this Client executes all operations
    let queue: DispatchQueue
    
    /// The certificate used by the client, if any
    public var clientCertificatePath: String? = nil
    
    /// Creates a new `TLSClient` by specifying a queue.
    ///
    /// Can throw an error if the initialization phase fails
    public init(on worker: Worker) throws {
        let socket = try TCPSocket()
        
        self.queue = worker.eventLoop.queue
        self.client = TCPClient(socket: socket, worker: worker)
        self.ssl = try SSLStream(socket: self.client, descriptor: socket.descriptor, queue: queue)
    }
    
    /// Attempts to connect to a server on the provided hostname and port
    public func connect(hostname: String, port: UInt16) throws -> Future<Void> {
        try client.socket.connect(hostname: hostname, port: port)
        
        // Continues setting up SSL after the socket becomes writable (successful connection)
        return client.socket.writable(queue: queue).flatMap {
            return try self.ssl.initializeClient(hostname: hostname, signedBy: self.clientCertificatePath)
        }.map {
            self.ssl.start()
        }
    }

    /// See InputStream.onInput
    public func onInput(_ input: ByteBuffer) {
        ssl.onInput(input)
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        ssl.onError(error)
    }

    /// See OutputStream.onOutput
    public func onOutput<I>(_ input: I) where I: Async.InputStream, TLSClient.Output == I.Input {
        ssl.onOutput(input)
    }

    /// See ClosableStream.onClose
    public func onClose(_ onClose: ClosableStream) {
        ssl.onClose(onClose)
    }

    /// See CloseableStream.close
    public func close() {
        ssl.close()
    }
}
