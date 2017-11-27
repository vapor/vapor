import Async
import Bits
import COpenSSL
import Dispatch

extension SSLStream {
    /// Runs the SSL handshake, regardless of client or server
    func handshake(for ssl: UnsafeMutablePointer<SSL>, side: Side) throws -> Future<Void> {
        var accepted = false
        
        func retry() -> Int32 {
            if case .client = side {
                return SSL_connect(ssl)
            } else if !accepted {
                return SSL_accept(ssl)
            } else {
                return SSL_do_handshake(ssl)
            }
        }
        
        let promise = Promise<Void>()
        
        var result: Int32 = 0
        var code: Int32 = 0
        
        func attemptInstantiation() {
            repeat {
                result = retry()
                code = SSL_get_error(ssl, result)
            } while result == -1 && (
                code == SSL_ERROR_WANT_READ ||
                code == SSL_ERROR_WANT_WRITE ||
                code == SSL_ERROR_WANT_READ ||
                code == SSL_ERROR_WANT_CONNECT
            )
            
            if case .server = side, !accepted {
                accepted = true
                return attemptInstantiation()
            }
            
            if result == -1 {
                promise.fail(OpenSSLError(.sslError(result)))
            } else {
                promise.complete(())
            }
        }
        
        attemptInstantiation()
        
        return promise.future
    }
    
    /// This is mandatory for SSL Servers to work. Optional for Clients.
    ///
    /// The certificate entered is the public key. The private key will be retreived from the keychain.
    ///
    /// You need to register the `.p12` file to the `login` keychain. The `.p12` must be associated with the public key certificate defined here.
    ///
    /// https://www.sslshopper.com/article-most-common-openssl-commands.html
    func setServerCertificates(certificatePath: String, keyPath: String) throws {
        guard let context = context else {
            throw OpenSSLError(.noSSLContext)
        }
        
        SSL_CTX_use_certificate_file(context, certificatePath, SSL_FILETYPE_PEM)
        
        var error = SSL_CTX_use_certificate_file(context, certificatePath, SSL_FILETYPE_PEM)
        
        guard error > 0 else {
            throw OpenSSLError(.sslError(error))
        }
        
        error = SSL_CTX_use_PrivateKey_file(context, keyPath, SSL_FILETYPE_PEM)
        
        guard error > 0 else {
            throw OpenSSLError(.sslError(error))
        }
    }
    
    /// Starts receiving data from the client, reads on the provided queue
    public func start() {
        readSource.setEventHandler {
            let read: Int
            do {
                read = try self.read(into: self.outputBuffer)
            } catch {
                // any errors that occur here cannot be thrown,
                // so send them to stream error catcher.
                self.onError(error)
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
        
        readSource.setCancelHandler {
            self.close()
        }
        
        readSource.resume()
        self.reading = true
        
        writeSource.setEventHandler {
            guard self.writeQueue.count > 0 else {
                if self.writing {
                    self.writeSource.suspend()
                }
                
                return
            }
            
            let data = self.writeQueue[0]
            
            data.withUnsafeBytes { (pointer: BytesPointer) in
                let buffer = UnsafeBufferPointer(start: pointer, count: data.count)
                
                do {
                    try self.write(from: buffer)
                    _ = self.writeQueue.removeFirst()
                } catch {
                    self.onError(error)
                }
            }
            
            guard self.writeQueue.count > 0 else {
                self.writeSource.suspend()
                self.writing = false
                return
            }
        }
        self.writing = true
    }
}
