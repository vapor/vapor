import Async
import TCP
import TLS
import Bits
import COpenSSL
import Dispatch
import Foundation
import COperatingSystem

enum SSLSettings {
    internal static var initialized: Bool = {
        SSL_library_init()
        SSL_load_error_strings()
        OPENSSL_config(nil)
        OPENSSL_add_all_algorithms_conf()
        return true
    }()
}

internal protocol OpenSSLStream: TLSStream {
    var socket: TCPSocket { get set }
    
    /// The `SSL` context that manages this stream
    var ssl: UnsafeMutablePointer<SSL> { get }
    
    /// The `SSL` context that manages this stream
    var context: UnsafeMutablePointer<SSL_CTX> { get }
    
    /// The file descriptor to write to/from
    var descriptor: Int32 { get set }
    
    /// The queue to read on
    var queue: DispatchQueue { get }
    
    var connected: Promise<Void> { get }
    
    /// Keeps a strong reference to the DispatchSourceRead so it keeps reading
    var readSource: DispatchSourceRead { get }
    
    /// A buffer of all data that still needs to be written
    var writeQueue: [Data] { get set }
    
    /// Keeps a strong reference to the DispatchSourceWrite so it can keep writing
    var writeSource: DispatchSourceWrite { get }
    
    /// A buffer storing all deciphered data received from the remote
    var outputBuffer: MutableByteBuffer { get }
    
    /// Use a basic output stream to implement server output stream.
    var outputStream: BasicStream<Output> { get }
    
    func handshake()
}

extension OpenSSLStream {
    /// See InputStream.onInput
    public func onInput(_ input: ByteBuffer) {
        do {
            try self.write(from: input)
        } catch {
            self.onError(error)
            self.close()
        }
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    public func onOutput<I>(_ input: I) where I: Async.InputStream, I.Input == ByteBuffer {
        outputStream.onOutput(input)
    }

    /// See ClosableStream.onClose
    public func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
    }
    
    /// Returns a boolean describing if the socket is still healthy and open
    public var isConnected: Bool {
        var error = 0
        getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &error, nil)
        
        return error == 0
    }
    
    public func close() {
        readSource.cancel()
        self.socket.close()
        outputStream.close()
    }
}

extension OpenSSLStream {
    /// Writes the buffer to this SSL socket
    @discardableResult
    func write(from buffer: ByteBuffer) throws -> Int {
        let written = SSL_write(ssl, buffer.baseAddress, Int32(buffer.count))
        
        guard written == buffer.count else {
            if written == 0 {
                self.close()
                return 0
            } else {
                throw OpenSSLError(.sslError(SSL_get_error(ssl, written)))
            }
        }
        
        return numericCast(written)
    }
    
    /// Reads from this SSL socket
    @discardableResult
    func read(into buffer: MutableByteBuffer) throws -> Int {
        let read = SSL_read(ssl, buffer.baseAddress!, Int32(buffer.count))
        
        if read == 0 {
            self.close()
            return 0
        } else if read < 0 {
            throw OpenSSLError(.sslError(SSL_get_error(ssl, read)))
        }
        
        return numericCast(read)
    }
}
