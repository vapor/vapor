import Async
import Bits
import Security
import Foundation
import Dispatch
import TLS
import TCP

public final class AppleSSLClient: AppleSSLStream, TLSClient {
    public typealias Output = ByteBuffer
    
    var handshakeComplete = false
    
    var writeSource: DispatchSourceWrite
    
    var socket: TCPSocket
    
    var writeQueue = [Data]()
    
    var readSource: DispatchSourceRead
    
    public var settings: TLSClientSettings
    
    public var peerDomainName: String?
    
    let connected = Promise<Void>()
    
    var outputStream = BasicStream<ByteBuffer>()
    
    public func connect(hostname: String, port: UInt16) throws -> Future<Void> {
        try socket.connect(hostname: hostname, port: port)
        return self.start()
    }
    
    var descriptor: UnsafeMutablePointer<Int32>
    
    let context: SSLContext
    
    var queue: DispatchQueue
    
    /// A buffer storing all deciphered data received from the remote
    let outputBuffer = MutableByteBuffer(
        start: .allocate(capacity: Int(UInt16.max)),
        count: Int(UInt16.max)
    )
    
    public convenience init(settings: TLSClientSettings, on eventLoop: EventLoop) throws {
        let socket = try TCPSocket()
        
        try self.init(upgrading: socket, settings: settings, on: eventLoop)
    }
    
    public init(upgrading socket: TCPSocket, settings: TLSClientSettings, on eventLoop: EventLoop) throws {
        self.socket = socket
        self.settings = settings
        
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
        
        self.writeSource.setEventHandler {
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
            guard self.handshakeComplete else {
                self.handshake(for: context).do {
                    self.readSource.resume()
                    self.connected.complete()
                    self.handshakeComplete = true
                }.catch(self.connected.fail)
                return
            }
            
            let read: Int
            do {
                read = try self.read(into: self.outputBuffer)
            } catch {
                // any errors that occur here cannot be thrown,
                // so send them to stream error catcher.
                self.onError(error)
                return
            }
            
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
        
        try self.initialize()
    }
    
    func start() -> Future<Void> {
        self.writeSource.resume()
        
        return connected.future
    }
    
    deinit {
        outputBuffer.baseAddress?.deallocate(capacity: outputBuffer.count)
        self.descriptor.deallocate(capacity: 1)
    }
}
