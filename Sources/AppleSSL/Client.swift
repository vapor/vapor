import Async
import Bits
import Security
import Foundation
import Dispatch
import TLS
import TCP

public final class AppleSSLClient: AppleSSLStream, SSLClient {
    public typealias Output = ByteBuffer
    
    var handshakeComplete = false
    
    var writeSource: DispatchSourceWrite
    
    var socket: TCPSocket
    
    var writeQueue: [Data]
    
    var readSource: DispatchSourceRead
    
    public var settings: SSLClientSettings
    
    public var peerDomainName: String?
    
    let connected = Promise<Void>()
    
    var outputStream = BasicStream<ByteBuffer>()
    
    /// Internal helper that asserts the success of an operation
    fileprivate func assert(status: OSStatus) throws {
        guard status == 0 else {
            throw AppleSSLError(.sslError(status))
        }
    }
    
    public func connect(hostname: String, port: UInt16) throws -> Future<Void> {
        if let peerDomainName = peerDomainName {
            try assert(status: SSLSetPeerDomainName(context, peerDomainName, peerDomainName.count))
        }
        
        try socket.connect(hostname: hostname, port: port)
        
        try self.initialize()
        
        return connected.future
    }
    
    var descriptor: UnsafeMutablePointer<Int32>
    
    let context: SSLContext
    
    var queue: DispatchQueue
    
    /// A buffer storing all deciphered data received from the remote
    let outputBuffer = MutableByteBuffer(
        start: .allocate(capacity: Int(UInt16.max)),
        count: Int(UInt16.max)
    )
    
    public convenience init(settings: SSLClientSettings, on eventLoop: EventLoop) throws {
        let socket = try TCPSocket()
        
        try self.init(upgrading: socket, settings: settings, on: eventLoop)
    }
    
    public init(upgrading socket: TCPSocket, settings: SSLClientSettings, on eventLoop: EventLoop) throws {
        self.socket = socket
        self.settings = settings
        self.writeQueue = []
        
        guard let context = SSLCreateContext(nil, .clientSide, .streamType) else {
            throw AppleSSLError(.cannotCreateContext)
        }
        
        self.context = context
        self.queue = eventLoop.queue
        
        self.readSource = DispatchSource.makeReadSource(
            fileDescriptor: socket.descriptor,
            queue: eventLoop.queue
        )
        
        self.writeSource = DispatchSource.makeWriteSource(fileDescriptor: socket.descriptor, queue: queue)
        
        self.descriptor = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        self.descriptor.pointee = self.socket.descriptor
        var handshakeSent = false
        
        self.writeSource.setEventHandler {
            guard handshakeSent else {
                self.writeSource.suspend()
                handshakeSent = true
                self.handshake()
                return
            }
            
            guard self.writeQueue.count > 0 else {
                self.writeSource.suspend()
                return
            }
            
            let data = self.writeQueue[0]
            
            let (status, processed) = data.withUnsafeBytes { (pointer: BytesPointer) -> (OSStatus, Int) in
                var processed = 0
                
                let status = SSLWrite(context, pointer, data.count, &processed)
                
                return (status, processed)
            }
            
            if status == 0, processed == data.count {
                _ = self.writeQueue.removeFirst()
            } else {
                self.writeQueue[0].removeFirst(processed)
            }
            
            guard self.writeQueue.count > 0 else {
                self.writeSource.suspend()
                return
            }
        }
        
        self.readSource.setEventHandler {
            guard self.connected.future.isCompleted else {
                self.handshake()
                return
            }
            
            let read = self.read(into: self.outputBuffer)
            
            guard read > 0 else {
                // need to close!!! gah
                self.close()
                return
            }
            
            // create a view into the internal buffer and
            // send to the output stream
            let bufferView = ByteBuffer(
                start: self.outputBuffer.baseAddress,
                count: read
            )
            
            self.outputStream.onInput(bufferView)
        }
        
        self.readSource.setCancelHandler {
            SSLClose(context)
            
            self.close()
        }
        
        self.readSource.resume()
        self.writeSource.resume()
    }
    
    deinit {
        outputBuffer.baseAddress?.deallocate(capacity: outputBuffer.count)
        self.descriptor.deallocate(capacity: 1)
    }
}
