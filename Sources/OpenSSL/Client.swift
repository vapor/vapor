import CTLS

/// An SSL client. Can be initialized by upgrading an existing socket or by starting an SSL socket.
extension SSLStream {
    /// Upgrades the connection to SSL.
    public func initializeClient(hostname: String, signedBy certificate: String? = nil) throws {
        let ssl = try self.initialize(side: .client)
        
        var hostname = [UInt8](hostname.utf8)
        SSL_ctrl(ssl, SSL_CTRL_SET_TLSEXT_HOSTNAME, Int(TLSEXT_NAMETYPE_host_name), &hostname)
        
        if let certificate = certificate {
            try self.setCertificate(toFileAt: certificate)
        }
        
        try handshake(for: ssl)
    }
    
    enum Side {
        case client
    }
    
    /// A helper that initializes SSL as either the client or server side
    func initialize(side: Side) throws -> UnsafeMutablePointer<SSL> {
        guard context == nil else {
            throw Error.contextAlreadyCreated
        }
        
        let method: UnsafePointer<SSL_METHOD>
        
        switch side {
        case .client:
            method = SSLv2_client_method()
        }
        
        guard let context = SSL_CTX_new(method) else {
            throw Error.cannotCreateContext
        }
        
        self.context = context
        
        guard let ssl = SSL_new(context) else {
            throw Error.noSSLContext
        }
        
        let status = SSL_set_fd(ssl, self.descriptor)
        
        guard status == 0 else {
            throw Error.sslError(status)
        }
        
        return ssl
    }
}
