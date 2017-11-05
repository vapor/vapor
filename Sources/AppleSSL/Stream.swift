import Async
import Bits
import Dispatch
import Foundation
import Security

/// A generic SSL socket based on Apple's Security Framework.
///
/// Subclasses TCP.Socket so it can be used in every TCP.Socket's place
///
/// Serves as a base for `AppleSSLClient` and `AppleSSLServer`.
///
/// Streams incoming raw data through SSL and as ciphertext to the other end.
///
/// The TCP socket will also be read and deciphered into plaintext and outputted.
///
/// https://developer.apple.com/documentation/security/secure_transport
public final class SSLStream<DuplexByteStream: Async.Stream>: Async.Stream, ClosableStream where DuplexByteStream.Notification == ByteBuffer, DuplexByteStream.Input == ByteBuffer, DuplexByteStream: ClosableStream {
    /// See `OutputStream.Notification`
    public typealias Notification = ByteBuffer
    
    /// See `InputStream.Input`
    public typealias Input = ByteBuffer
    
    /// See `OutputStream.outputStream`
    public var outputStream: NotificationCallback?
    
    /// See `ClosableStream.closeNotification`
    public let closeNotification = SingleNotification<Void>()
    
    /// See `Stream.errorStream`
    public let errorNotification = SingleNotification<Error>()
    
    /// The `SSLContext` that manages this stream
    var context: SSLContext?
    
    /// The underlying TCP socket
    let socket: DuplexByteStream
    
    /// The queue to read on
    let queue: DispatchQueue
    
    /// A buffer storing all deciphered data received from the remote
    let outputBuffer = MutableByteBuffer(start: .allocate(capacity: Int(UInt16.max)), count: Int(UInt16.max))
    
    /// Used to give reference/pointer access to the descriptor to SSL
    var descriptor: Int32
    
    /// Keeps a strong reference to the DispatchSourceRead so it keeps reading
    var readSource: DispatchSourceRead?
    
    /// A buffer of all data that still needs to be written
    var writeQueue = [Data]()
    
    /// Keeps a strong reference to the DispatchSourceWrite so it can keep writing
    let writeSource: DispatchSourceWrite
    
    deinit {
        outputBuffer.baseAddress?.deallocate(capacity: outputBuffer.count)
    }
    
    /// Creates a new SSLStream on top of a socket
    public init(socket: DuplexByteStream, descriptor: Int32, queue: DispatchQueue) throws {
        self.socket = socket
        self.descriptor = descriptor
        self.queue = queue
        
        self.writeSource = DispatchSource.makeWriteSource(fileDescriptor: descriptor, queue: queue)
        
        self.writeSource.setEventHandler {
            guard self.writeQueue.count > 0 else {
                self.writeSource.suspend()
                return
            }
            
            let data = self.writeQueue[0]
            
            data.withUnsafeBytes { (pointer: BytesPointer) in
                let buffer = UnsafeBufferPointer(start: pointer, count: data.count)
                
                do {
                    try self.write(from: buffer, allowWouldBlock: false)
                    _ = self.writeQueue.removeFirst()
                } catch {
                    self.errorNotification.notify(of: error)
                }
            }
            
            guard self.writeQueue.count > 0 else {
                self.writeSource.suspend()
                return
            }
        }
    }
    
    /// Writes the buffer to this SSL socket
    @discardableResult
    public func write(from buffer: ByteBuffer) throws -> Int {
        return try self.write(from: buffer, allowWouldBlock: true)
    }
    
    /// Reads from this SSL socket
    @discardableResult
    public func read(into buffer: MutableByteBuffer) throws -> Int {
        guard let context = self.context else {
            close()
            throw SSLError(.noSSLContext)
        }
        
        var processed = 0
        
        SSLRead(context, buffer.baseAddress!, buffer.count, &processed)
        
        return processed
    }
    
    /// Accepts a `ByteBuffer` as plain data that will be send as ciphertext using SSL.
    public func inputStream(_ input: ByteBuffer) {
        do {
            try self.write(from: input)
        } catch {
            self.errorNotification.notify(of: error)
            self.close()
        }
    }
    
    /// Closes the connection
    public func close() {
        guard let readSource = readSource else {
            socket.close()
            return
        }
        
        readSource.cancel()
        
        if writeQueue.count > 0 {
            writeSource.cancel()
        }
    }
}
