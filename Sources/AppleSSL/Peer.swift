import Async
import Bits
import Security
import Foundation
import Dispatch
import TLS
import TCP

public final class AppleSSLPeer: AppleSSLStream, SSLPeer {
    public typealias Output = ByteBuffer
    
    var handshakeComplete = false
    
    var writeSource: DispatchSourceWrite
    
    var socket: TCPSocket
    
    var writeQueue: [Data]
    
    var readSource: DispatchSourceRead
    
    public var settings: SSLServerSettings
    
    let connected = Promise<Void>()
    
    var descriptor: UnsafeMutablePointer<Int32>
    
    let context: SSLContext
    
    var queue: DispatchQueue
    
    /// A buffer storing all deciphered data received from the remote
    let outputBuffer = MutableByteBuffer(
        start: .allocate(capacity: Int(UInt16.max)),
        count: Int(UInt16.max)
    )
    
    var outputStream = BasicStream<ByteBuffer>()
    
    public convenience init(settings: SSLServerSettings, on eventLoop: EventLoop) throws {
        let socket = try TCPSocket()
        
        try self.init(upgrading: socket, settings: settings, on: eventLoop)
    }
    
    public init(upgrading socket: TCPSocket, settings: SSLServerSettings, on eventLoop: EventLoop) throws {
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
        
        try self.setCertificate(to: settings.serverCertificate, for: context)
        
        try self.initialize()
        
        self.writeSource.resume()
    }
    
    deinit {
        outputBuffer.baseAddress?.deallocate(capacity: outputBuffer.count)
        self.descriptor.deallocate(capacity: 1)
    }
}
