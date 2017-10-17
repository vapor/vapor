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
    /// See `OutputStream.Output`
    public typealias Output = ByteBuffer
    
    /// See `InputStream.Input`
    public typealias Input = ByteBuffer
    
    /// See `OutputStream.outputStream`
    public var outputStream: OutputHandler? {
        get {
            return ssl.outputStream
        }
        set {
            ssl.outputStream = newValue
        }
    }
    
    /// See `BaseStream.onClose`
    public var onClose: CloseHandler? {
        get {
            return ssl.onClose
        }
        set {
            ssl.onClose = newValue
        }
    }
    
    /// See `Stream.errorStream`
    public var errorStream: ErrorHandler? {
        get {
            return ssl.errorStream
        }
        set {
            ssl.errorStream = newValue
        }
    }
    
    /// The AppleSSL (macOS/iOS) or OpenSSL (Linux) stream
    let ssl: SSLStream<TCPClient>
    
    /// The TCP that is used in the SSL Stream
    let client: TCPClient
    
    /// A DispatchQueue on which this Client executes all operations
    let queue: DispatchQueue
    
    /// The certificate used by the client, if any
    public var clientCertificatePath: String? = nil
    
    public var protocols = [String]() {
        didSet {
            preferences = ALPNPreferences(array: protocols)
        }
    }
    
    var preferences: ALPNPreferences = []
    
    /// Creates a new `TLSClient` by specifying a queue.
    ///
    /// Can throw an error if the initialization phase fails
    public init(worker: Worker) throws {
        let socket = try Socket()
        
        self.queue = worker.queue
        self.client = TCPClient(socket: socket, worker: worker)
        self.ssl = try SSLStream(socket: self.client, descriptor: socket.descriptor, queue: queue)
    }
    
    /// Attempts to connect to a server on the provided hostname and port
    public func connect(hostname: String, port: UInt16) throws -> Future<Void> {
        try client.socket.connect(hostname: hostname, port: port)
        
        // Continues setting up SSL after the socket becomes writable (successful connection)
        return client.socket.writable(queue: queue).flatten {
            var options = [SSLOption]()
            
            options.append(.peerDomainName(hostname))
            
            if self.protocols.count > 0 {
                options.append(.alpn(protocols: self.preferences))
            }
            
            return try self.ssl.initializeClient(options: options)
        }.map {
            self.ssl.start()
        }
    }
    
    /// Used for sending data over TLS
    public func inputStream(_ input: ByteBuffer) {
        ssl.inputStream(input)
    }
    
    public func close() {
        ssl.close()
    }
}
