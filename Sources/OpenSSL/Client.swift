import Async
import COpenSSL

/// An SSL client. Can be initialized by upgrading an existing socket or by starting an SSL socket.
extension SSLStream {
    /// Upgrades the connection to SSL.
    public func initializeClient(hostname: String, signedBy certificate: String? = nil) throws -> Future<Void> {
        let ssl = try self.initialize(side: .client, method: .ssl23)
        
        var hostname = [UInt8](hostname.utf8)
        SSL_ctrl(ssl, SSL_CTRL_SET_TLSEXT_HOSTNAME, Int(TLSEXT_NAMETYPE_host_name), &hostname)
        
        if let certificate = certificate {
            try self.setCertificate(certificatePath: certificate)
        }
        
        return try handshake(for: ssl, side: .client)
    }
    
    /// The type of handshake to perform
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
    
    /// A helper that initializes SSL as either the client or server side
    func initialize(side: Side, method: Method) throws -> UnsafeMutablePointer<SSL> {
        guard SSLSettings.initialized else {
            throw Error(.notInitialized)
        }
        
        guard context == nil else {
            throw Error(.contextAlreadyCreated)
        }
        
        let method: UnsafePointer<SSL_METHOD>
        
        switch side {
        case .client:
            method = SSLv23_client_method()
        case .server(_, _):
            method = TLSv1_2_server_method()
        }
        
        guard let context = SSL_CTX_new(method) else {
            throw Error(.cannotCreateContext)
        }
        
        guard SSL_CTX_set_cipher_list(context, "DEFAULT") == 1 else {
            throw Error(.cannotCreateContext)
        }
        
        self.context = context
        
        if case .server(let certificate, let key) = side {
            try self.setServerCertificates(certificatePath: certificate, keyPath: key)
        }
        
        guard let ssl = SSL_new(context) else {
            throw Error(.noSSLContext)
        }
        
        let status = SSL_set_fd(ssl, self.descriptor)
        
        guard status > 0 else {
            throw Error(.sslError(status))
        }
        
        self.ssl = ssl
        
        return ssl
    }
}
