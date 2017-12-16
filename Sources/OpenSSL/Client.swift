import Async
import Foundation
import TCP
import TLS
import Dispatch
import Bits
import COpenSSL

public final class OpenSSLClient: OpenSSLStream, SSLClient {
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
    
    public var settings: SSLClientSettings
    
    public var peerDomainName: String?
    
    let connected = Promise<Void>()
    
    var outputStream = BasicStream<ByteBuffer>()
    
    public func connect(hostname: String, port: UInt16) throws -> Future<Void> {
        var hostname = hostname
        SSL_ctrl(ssl, SSL_CTRL_SET_TLSEXT_HOSTNAME, Int(TLSEXT_NAMETYPE_host_name), &hostname)
        
        try socket.connect(hostname: hostname, port: port)
        
        return connected.future
    }
    
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
    
    init(upgrading socket: TCPSocket, settings: SSLClientSettings, on eventLoop: EventLoop) throws {
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
        
        self.readSource = DispatchSource.makeReadSource(
            fileDescriptor: socket.descriptor,
            queue: eventLoop.queue
        )
        
        self.writeSource = DispatchSource.makeWriteSource(fileDescriptor: socket.descriptor, queue: queue)
        
        self.readSource.resume()
        self.writeSource.resume()
    }
    
    /// Runs the SSL handshake, regardless of client or server
    func handshake() {
        let result = SSL_connect(ssl)
        
        if result >= 0 {
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

