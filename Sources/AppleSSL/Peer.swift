import Async
import Bits
import Security
import Foundation
import Dispatch
import TLS
import TCP

/// An SSL server-side connection that makes use of Apple's Security libraries
public final class AppleSSLPeer: AppleSSLStream, SSLPeer {
    public typealias Output = ByteBuffer
    
    /// The underlying socket
    var socket: TCPSocket
    
    /// A buffer of all data that still needs to be written
    var writeQueue: [Data]
    
    /// Keeps a strong reference to the DispatchSourceWrite so it can keep writing
    var writeSource: DispatchSourceWrite
    
    /// Keeps a strong reference to the DispatchSourceRead so it keeps reading
    var readSource: DispatchSourceRead
    
    /// The SSL server side connection's settings
    public var settings: SSLServerSettings
    
    /// Keeps track of the successful or unsuccessful handshake and connection phase
    let connected = Promise<Void>()
    
    /// A pointer to the descriptor to be used for the SSLContext
    var descriptor: UnsafeMutablePointer<Int32>
    
    /// The `SSLContext` that manages this stream
    let context: SSLContext
    
    /// The queue to read on
    var queue: DispatchQueue
    
    /// A buffer storing all deciphered data received from the remote
    let outputBuffer = MutableByteBuffer(
        start: .allocate(capacity: Int(UInt16.max)),
        count: Int(UInt16.max)
    )
    
    /// Use a basic output stream to implement socket output stream.
    var outputStream = BasicStream<ByteBuffer>()
    
    /// Upgrades an existing TCP socket
    init(upgrading socket: TCPSocket, settings: SSLServerSettings, on eventLoop: EventLoop) throws {
        self.socket = socket
        self.settings = settings
        self.writeQueue = []
        
        self.descriptor = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        self.descriptor.pointee = self.socket.descriptor
        
        guard let context = SSLCreateContext(nil, .serverSide, .streamType) else {
            throw AppleSSLError(.cannotCreateContext)
        }
        
        self.context = context
        self.queue = eventLoop.queue
        
        self.readSource = DispatchSource.makeReadSource(
            fileDescriptor: socket.descriptor,
            queue: eventLoop.queue
        )
        
        self.writeSource = DispatchSource.makeWriteSource(fileDescriptor: socket.descriptor, queue: queue)
        
        self.initializeDispatchSources()
        
        defer {
            // Required, cannot deinitialize a non-running readsource
            self.readSource.resume()
        }
        
        try self.setCertificate(to: settings.publicKey, for: context)
        
        try self.initialize()
        
        self.writeSource.resume()
    }
    
    deinit {
        outputBuffer.baseAddress?.deallocate(capacity: outputBuffer.count)
        self.descriptor.deallocate(capacity: 1)
    }
}
