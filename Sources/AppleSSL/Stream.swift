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
    /// The underlying socket
    var socket: TCPSocket { get set }
    
    /// A pointer to the descriptor to be used for the SSLContext
    var descriptor: UnsafeMutablePointer<Int32> { get }

    /// The `SSLContext` that manages this stream
    var context: SSLContext { get }
    
    /// The queue to read on
    var queue: DispatchQueue { get }
    
    /// Keeps a strong reference to the DispatchSourceWrite so it can keep writing
    var writeSource: DispatchSourceWrite { get }
    
    /// Keeps track of the successful or unsuccessful handshake and connection phase
    var connected: Promise<Void> { get }
    
    /// A buffer of all data that still needs to be written
    var writeQueue: [Data] { get set }
    
    /// Keeps a strong reference to the DispatchSourceRead so it keeps reading
    var readSource: DispatchSourceRead { get }
    
    /// Use a basic output stream to implement socket output stream.
    var outputStream: BasicStream<Output> { get }
    
    /// A buffer storing all deciphered data received from the remote
    var outputBuffer: MutableByteBuffer { get }
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
    
    func initializeDispatchSources() {
        self.writeSource.setEventHandler {
            guard self.connected.future.isCompleted else {
                self.handshake()
                self.writeSource.suspend()
                return
            }
            
            guard self.writeQueue.count > 0 else {
                self.writeSource.suspend()
                return
            }
            
            let data = self.writeQueue[0]
            
            let (status, processed) = data.withUnsafeBytes { (pointer: BytesPointer) -> (OSStatus, Int) in
                var processed = 0
                
                let status = SSLWrite(self.context, pointer, data.count, &processed)
                
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
            SSLClose(self.context)
            
            self.close()
        }
    }
}
