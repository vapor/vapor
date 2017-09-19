#if os(macOS) || os(iOS)
    import Core
    import Foundation
    import Security
    
    extension AppleSSLSocket {
        /// Runs the SSL handshake, regardless of client or server
        func handshake(for context: SSLContext) throws {
            var result: Int32
            
            repeat {
                result = SSLHandshake(context)
            } while result == errSSLWouldBlock
            
            guard result == errSecSuccess || result == errSSLPeerAuthCompleted else {
                throw Error.sslError(result)
            }
        }
        
        /// Sets the certificate regardless of Client/Server.
        ///
        /// This is mandatory for SSL Servers to work. Optional for Clients.
        ///
        /// The certificate entered is the public key. The private key will be retreived from the keychain.
        ///
        /// You need to register the `.p12` file to the `login` keychain. The `.p12` must be associated with the public key certificate defined here.
        ///
        /// https://www.sslshopper.com/article-most-common-openssl-commands.html
        public func setCertificate(to certificate: Certificate, for context: SSLContext) throws {
            guard let certificate = SecCertificateCreateWithData(nil, certificate.data as CFData) else {
                throw Error.invalidCertificate
            }
            
            var ref: SecIdentity?
            
            var error = SecIdentityCreateWithCertificate(nil, certificate, &ref)
            
            guard error == errSecSuccess else {
                throw Error.invalidCertificate
            }
            
            error = SSLSetCertificate(context, [ref as Any, certificate] as CFArray)
            
            guard error == errSecSuccess else {
                throw Error.invalidCertificate
            }
        }
        
        /// Starts receiving data from the client, reads on the provided queue
        public func start(on queue: DispatchQueue) {
            let source = DispatchSource.makeReadSource(
                fileDescriptor: self.descriptor,
                queue: queue
            )
            
            source.setEventHandler {
                let read: Int
                do {
                    read = try self.read(
                        max: self.outputBuffer.count,
                        into: self.outputBuffer
                    )
                } catch {
                    // any errors that occur here cannot be thrown,
                    // so send them to stream error catcher.
                    self.errorStream?(error)
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
                self.outputStream?(bufferView)
            }
            
            source.setCancelHandler {
                self.close()
            }
            
            source.resume()
            self.source = source
        }
    }
#endif
