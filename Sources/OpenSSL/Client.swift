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
        if !SSLSettings.initialized {
            SSL_library_init()
            SSL_load_error_strings()
            OPENSSL_config(nil)
            OPENSSL_add_all_algorithms_conf()
            SSLSettings.initialized = true
        }
        
        guard context == nil else {
            throw Error.contextAlreadyCreated
        }
        
        let method: UnsafePointer<SSL_METHOD>
        
        switch side {
        case .client:
            method = SSLv23_client_method()
        }
        
        guard let context = SSL_CTX_new(method) else {
            throw Error.cannotCreateContext
        }
        
        SSL_CTX_ctrl(context, SSL_CTRL_MODE, SSL_MODE_AUTO_RETRY, nil)
        SSL_CTX_ctrl(context, SSL_CTRL_OPTIONS, SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3 | SSL_OP_NO_COMPRESSION, nil)
        
        guard SSL_CTX_set_cipher_list(context, "DEFAULT") == 1 else {
            throw Error.cannotCreateContext
        }
        
        self.context = context
        
        guard let ssl = SSL_new(context) else {
            throw Error.noSSLContext
        }
        
        let status = SSL_set_fd(ssl, self.descriptor)
        
        guard status > 0 else {
            throw Error.sslError(status)
        }
        
        return ssl
    }
}
