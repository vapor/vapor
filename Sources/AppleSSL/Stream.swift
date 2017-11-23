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
public final class SSLStream: Async.Stream {
    /// See OutputStream.Output
    public typealias Output = ByteBuffer
    
    /// See InputStream.Input
    public typealias Input = ByteBuffer

    /// Used to give reference/pointer access to the descriptor to SSL
    internal var descriptor: Int32

    /// The `SSLContext` that manages this stream
    internal var context: SSLContext?

    /// Keeps a strong reference to the DispatchSourceWrite so it can keep writing
    internal let writeSource: DispatchSourceWrite

    /// A buffer of all data that still needs to be written
    internal var writeQueue = [Data]()

    /// The queue to read on
    internal let queue: DispatchQueue
    
    /// A buffer storing all deciphered data received from the remote
    internal let outputBuffer = MutableByteBuffer(
        start: .allocate(capacity: Int(UInt16.max)),
        count: Int(UInt16.max)
    )

    /// Keeps a strong reference to the DispatchSourceRead so it keeps reading
    internal var readSource: DispatchSourceRead?

    /// Use a basic output stream to implement server output stream.
    internal var outputStream: BasicStream<Output> = .init()

    /// The underlying TCP socket
    private let socket: ClosableStream
    
    /// Creates a new SSLStream on top of a socket
    public init<ByteStream>(socket: ByteStream, descriptor: Int32, queue: DispatchQueue) throws
        where ByteStream: Async.Stream,
        ByteStream.Output == ByteBuffer,
        ByteStream.Input == ByteBuffer,
        ByteStream: ClosableStream
    {
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
                    self.onError(error)
                }
            }
            
            guard self.writeQueue.count > 0 else {
                self.writeSource.suspend()
                return
            }
        }
    }

    /// See InputStream.onInput
    public func onInput(_ input: ByteBuffer) {
        do {
            try write(from: input)
        } catch {
            onError(error)
        }
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    public func onOutput<I>(_ input: I) where I: Async.InputStream, SSLStream.Output == I.Input {
        outputStream.onOutput(input)
    }

    /// See ClosableStream.onClose
    public func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
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
            throw AppleSSLError(.noSSLContext)
        }
        
        var processed = 0
        SSLRead(context, buffer.baseAddress!, buffer.count, &processed)
        return processed
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
        outputStream.close()
    }

    deinit {
        outputBuffer.baseAddress?.deallocate(capacity: outputBuffer.count)
    }
}
