import Async
import Foundation
import TCP
import TLS
import Dispatch
import Bits
import COpenSSL

enum Side {
    case client
    case server(certificate: String, key: String)
}

enum Method {
    case ssl23
    case tls1_0
    case tls1_1
    case tls1_2
    
    func method(side: Side) -> UnsafePointer<SSL_METHOD> {
        switch side {
        case .client:
            switch self {
            case .ssl23: return SSLv23_client_method()
            case .tls1_0: return TLSv1_client_method()
            case .tls1_1: return TLSv1_1_client_method()
            case .tls1_2: return TLSv1_2_client_method()
            }
        case .server(_, _):
            switch self {
            case .ssl23: return SSLv23_server_method()
            case .tls1_0: return TLSv1_server_method()
            case .tls1_1: return TLSv1_1_server_method()
            case .tls1_2: return TLSv1_2_server_method()
            }
        }
    }
}

public final class OpenSSLClient: OpenSSLStream, TLSClient {
    public typealias Output = ByteBuffer
    
    var descriptor: Int32
    
    var handshakeComplete = false
    
    var writeSource: DispatchSourceWrite
    
    var socket: TCPSocket
    
    var writeQueue = [Data]()
    
    /// The `SSL` context that manages this stream
    var ssl: UnsafeMutablePointer<SSL>
    
    /// The `SSL` context that manages this stream
    var context: UnsafeMutablePointer<SSL_CTX>
    
    
    var readSource: DispatchSourceRead
    
    public var settings: TLSClientSettings
    
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
    
    public convenience init(settings: TLSClientSettings, on eventLoop: EventLoop) throws {
        let socket = try TCPSocket()
        
        try self.init(upgrading: socket, settings: settings, on: eventLoop)
    }
    
    public init(upgrading socket: TCPSocket, settings: TLSClientSettings, on eventLoop: EventLoop) throws {
        self.socket = socket
        self.settings = settings
        
        let method = Method.ssl23.method(side: .client)
        
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
        
        self.writeSource.setEventHandler {
            guard self.handshakeComplete else {
                self.writeSource.suspend()
                self.handshake()
                return
            }
            
            guard self.writeQueue.count > 0 else {
                self.writeSource.suspend()
                return
            }
            
            let data = self.writeQueue[0]
            
            let processed = data.withUnsafeBytes { (pointer: BytesPointer) -> Int in
                return numericCast(SSL_write(ssl, pointer, numericCast(data.count)))
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
                self.handshake()
                return
            }
            
            let read: Int
            
            do {
                read = try self.read(into: self.outputBuffer)
            } catch {
                self.onError(error)
                self.close()
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
            self.close()
        }
        
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

