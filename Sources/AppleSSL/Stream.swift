#if os(macOS) || os(iOS)
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
    public final class SSLStream<OS: Async.Stream>: Async.Stream where OS.Output == ByteBuffer, OS.Input == ByteBuffer, OS: ClosableStream {
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
        
        /// The `SSLContext` that manages this stream
        var context: SSLContext?
        
        /// The underlying TCP socket
        let socket: OS
        
        /// A buffer storing all deciphered data received from the remote
        let outputBuffer = MutableByteBuffer(start: .allocate(capacity: Int(UInt16.max)), count: Int(UInt16.max))
        
        /// Used to give reference/pointer access to the descriptor to SSL
        var descriptor: Int32
        
        /// Keeps a strong reference to the DispatchSource so it keeps reading
        var source: DispatchSourceRead?
        
        deinit {
            outputBuffer.baseAddress?.deallocate(capacity: outputBuffer.count)
        }
        
        /// Creates a new SSLStream on top of a socket
        public init(socket: OS, descriptor: Int32) throws {
            self.socket = socket
            self.descriptor = descriptor
        }
        
        /// Writes the buffer to this SSL socket
        @discardableResult
        public func write(max: Int, from buffer: ByteBuffer) throws -> Int {
            guard let context = self.context else {
                close()
                throw Error.noSSLContext
            }
            
            var processed = 0
            
            let status = SSLWrite(context, buffer.baseAddress, buffer.count, &processed)
            
            guard status > 0 else {
                if status == 0 {
                    self.close()
                    return 0
                } else {
                    throw Error.sslError(status)
                }
            }
            
            return processed
        }
        
        /// Reads from this SSL socket
        @discardableResult
        public func read(max: Int, into buffer: MutableByteBuffer) throws -> Int {
            guard let context = self.context else {
                close()
                throw Error.noSSLContext
            }
            
            var processed = 0
            
            SSLRead(context, buffer.baseAddress!, buffer.count, &processed)
            
            return processed
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
        
        /// Closes the connection
        public func close() {
            if let context = context {
                SSLClose(context)
            }
            
            socket.close()
        }
    }
#endif
