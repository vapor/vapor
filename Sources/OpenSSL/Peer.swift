import Async
import Foundation
import TCP
import TLS
import Dispatch
import Bits
import COpenSSL

public final class OpenSSLPeer: OpenSSLStream, SSLPeer {
    public typealias Output = ByteBuffer
    
    var descriptor: Int32
    
    var handshakeComplete = false
    
    var writeSource: DispatchSourceWrite
    
    var socket: TCPSocket
    
    var writeQueue: [Data]
    
    /// The `SSL` context that manages this stream
    var ssl: UnsafeMutablePointer<SSL>
    
    /// The `SSL` context that manages this stream
    var context: UnsafeMutablePointer<SSL_CTX>
    
    var readSource: DispatchSourceRead
    
    public var settings: SSLServerSettings
    
    let connected = Promise<Void>()
    
    var outputStream = BasicStream<ByteBuffer>()
    
    var queue: DispatchQueue
    
    /// A buffer storing all deciphered data received from the remote
    let outputBuffer = MutableByteBuffer(
        start: .allocate(capacity: Int(UInt16.max)),
        count: Int(UInt16.max)
    )
    
    public convenience init(settings: SSLServerSettings, on eventLoop: EventLoop) throws {
        let socket = try TCPSocket()
        
        try self.init(upgrading: socket, settings: settings, on: eventLoop)
    }
    
    init(upgrading socket: TCPSocket, settings: SSLServerSettings, on eventLoop: EventLoop) throws {
        self.socket = socket
        self.settings = settings
        self.writeQueue = []
        
        let method = OpenSSLMethod.ssl23.method(side: .client)
        
        guard SSLSettings.initialized, let context = SSL_CTX_new(method) else {
            throw OpenSSLError(.cannotCreateContext)
        }
        
        guard SSL_CTX_set_cipher_list(context, "DEFAULT") == 1 else {
            throw OpenSSLError(.cannotCreateContext)
        }
        
        guard let ssl = SSL_new(context) else {
            throw OpenSSLError(.noSSLContext)
        }
        
        let status = SSL_set_fd(ssl, socket.descriptor)
        
        guard status > 0 else {
            throw OpenSSLError(.sslError(status))
        }
        
        self.ssl = ssl
        
        self.context = context
        self.descriptor = socket.descriptor
        self.queue = eventLoop.queue
        
        // Set up the certificate
        var hostname = settings.hostname
        SSL_ctrl(ssl, SSL_CTRL_SET_TLSEXT_HOSTNAME, Int(TLSEXT_NAMETYPE_host_name), &hostname)
        
        try assert(SSL_CTX_use_certificate_file(context, settings.publicKey, SSL_FILETYPE_PEM))
        
        try assert(SSL_CTX_use_PrivateKey_file(context, settings.privateKey, SSL_FILETYPE_PEM))
        
        SSL_set_accept_state(ssl)
        
        self.readSource = DispatchSource.makeReadSource(
            fileDescriptor: socket.descriptor,
            queue: eventLoop.queue
        )
        
        self.writeSource = DispatchSource.makeWriteSource(fileDescriptor: socket.descriptor, queue: queue)
        self.initializeDispatchSources()
        
        self.readSource.resume()
        self.writeSource.resume()
    }
    
    /// Runs the SSL handshake, regardless of client or server
    func handshake() {
        let result = SSL_accept(ssl)
        
        if result == 1 {
            self.connected.complete()
            self.handshakeComplete = true
            
            return
        }
        
        let code = SSL_get_error(ssl, result)
        
        guard
            code == SSL_ERROR_WANT_READ ||
            code == SSL_ERROR_WANT_WRITE ||
            code == SSL_ERROR_WANT_READ ||
            code == SSL_ERROR_WANT_CONNECT
        else {
            self.connected.fail(OpenSSLError(.sslError(result)))
            return
        }
    }
    
    deinit {
        outputBuffer.baseAddress?.deallocate(capacity: outputBuffer.count)
    }
}

