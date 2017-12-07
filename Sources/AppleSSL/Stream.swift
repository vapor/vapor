import Async
import TLS
import Bits
import Dispatch
import Foundation
import Security
import TCP

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
protocol AppleSSLStream: TLSStream {
    var socket: TCPSocket { get set }
    
    var descriptor: UnsafeMutablePointer<Int32> { get }

    /// The `SSLContext` that manages this stream
    var context: SSLContext { get }
    
    /// Indicates the handshake is completed and normal socket operations can work
    var handshakeComplete: Bool { get set }

    /// The queue to read on
    var queue: DispatchQueue { get }
    
    /// Keeps a strong reference to the DispatchSourceWrite so it can keep writing
    var writeSource: DispatchSourceWrite { get }
    
    /// A buffer of all data that still needs to be written
    var writeQueue: [Data] { get set }
    
    /// Keeps a strong reference to the DispatchSourceRead so it keeps reading
    var readSource: DispatchSourceRead { get }
    
    /// Use a basic output stream to implement server output stream.
    var outputStream: BasicStream<Output> { get }
}

extension AppleSSLStream {
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
    public func onOutput<I: Async.InputStream>(_ input: I) where I.Input == Output {
        outputStream.onOutput(input)
    }
    
    /// See ClosableStream.onClose
    public func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
    }
    
    /// Closes the connection
    public func close() {
        socket.close()
        
        outputStream.close()
    }
}
