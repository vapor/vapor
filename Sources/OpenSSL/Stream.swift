import Async
import Bits
import CTLS
import Dispatch
import libc

enum SSLSettings {
    internal static var initialized = false
}

public final class SSLStream<DuplexByteStream: Async.Stream>: Async.Stream where DuplexByteStream.Output == ByteBuffer, DuplexByteStream.Input == ByteBuffer, DuplexByteStream: ClosableStream {
    /// See `OutputStream.Output`
    public typealias Output = ByteBuffer
    
    /// See `InputStream.Input`
    public typealias Input = ByteBuffer
    
    /// See `OutputStream.outputStream`
    public var outputStream: OutputHandler?
    
    /// See `BaseStream.onClose`
    public var onClose: CloseHandler?
    
    /// See `Stream.errorStream`
    public var errorStream: ErrorHandler?
    
    /// The `SSL` context that manages this stream
    var ssl: UnsafeMutablePointer<SSL>?
    
    /// The `SSL` context that manages this stream
    var context: UnsafeMutablePointer<SSL_CTX>?
    
    /// The file descriptor to write to/from
    var descriptor: Int32
    
    /// The underlying TCP socket
    let socket: DuplexByteStream
    
    /// Keeps a strong reference to the DispatchSource so it keeps reading
    var source: DispatchSourceRead?
    
    /// A buffer storing all deciphered data received from the remote
    let outputBuffer = MutableByteBuffer(start: .allocate(capacity: Int(UInt16.max)), count: Int(UInt16.max))
    
    deinit {
        outputBuffer.baseAddress?.deallocate(capacity: outputBuffer.count)
    }
    
    /// Creates a new SSLStream on top of a socket
    public init(socket: DuplexByteStream, descriptor: Int32) throws {
        self.socket = socket
        self.descriptor = descriptor
    }
    
    /// Writes the buffer to this SSL socket
    @discardableResult
    public func write(max: Int, from buffer: ByteBuffer) throws -> Int {
        guard let ssl = ssl else {
            close()
            throw Error(.noSSLContext)
        }
        
        let written = SSL_write(ssl, buffer.baseAddress, Int32(buffer.count))
        
        guard written > 0 else {
            if written == 0 {
                self.close()
                return 0
            } else {
                throw Error(.sslError(SSL_get_error(ssl, written)))
            }
        }
        
        return numericCast(written)
    }
    
    /// Reads from this SSL socket
    @discardableResult
    public func read(max: Int, into buffer: MutableByteBuffer) throws -> Int {
        guard let ssl = ssl else {
            close()
            throw Error(.noSSLContext)
        }
        
        let read = SSL_read(ssl, buffer.baseAddress!, Int32(buffer.count))
        
        if read == 0 {
            self.close()
            return 0
        } else if read < 0 {
            throw Error(.sslError(SSL_get_error(ssl, read)))
        }
        
        return numericCast(read)
    }
    
    /// Accepts a `ByteBuffer` as plain data that will be send as ciphertext using SSL.
    public func inputStream(_ input: ByteBuffer) {
        do {
            try self.write(max: input.count, from: input)
        } catch {
            self.errorStream?(error)
            self.close()
        }
    }
    
    public func close() {
        guard let source = source else {
            socket.close()
            return
        }
        
        source.cancel()
    }
}
