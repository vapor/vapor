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
        
        var result = retry()
        var code = SSL_get_error(ssl, result)
        
        // If the success is immediate
        if result == 0 {
            return Future(())
        }
        
        // Otherwise set up a readsource
        let readSource = DispatchSource.makeReadSource(fileDescriptor: self.descriptor, queue: self.queue)
        let promise = Promise<Void>()
        
        func tryAgain() {
            // On input, continue the handshake
            result = retry()
            code = SSL_get_error(ssl, result)
            
            if result == -1 && (
                code == SSL_ERROR_WANT_READ ||
                code == SSL_ERROR_WANT_WRITE ||
                code == SSL_ERROR_WANT_CONNECT ||
                code == SSL_ERROR_WANT_ACCEPT
            ) {
                return
            }
            
            // If it's not blocking and not a success, it's an error
            guard result > 0 else {
                readSource.cancel()
                promise.fail(OpenSSLError(.sslError(result)))
                return
            }
            
            if accepted {
                readSource.cancel()
                promise.complete(())
            } else {
                accepted = true
                tryAgain()
            }
        }
        
        // Listen for input
        readSource.setEventHandler {
            tryAgain()
        }
        
        // Now that the async stuff's et up, let's start your engines
        readSource.resume()
        
        let future = promise.future
        
        future.addAwaiter { _ in
            self.readSource = nil
        }
        
        self.readSource = readSource
        
        return future
    }
    
    func setCertificate(certificatePath: String) throws {
        guard let context = context else {
            throw OpenSSLError(.noSSLContext)
        }
        
        SSL_CTX_load_verify_locations(context, certificatePath, nil)
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
        let source = DispatchSource.makeReadSource(
            fileDescriptor: self.descriptor,
            queue: self.queue
        )
        
        source.setEventHandler {
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
        
        source.setCancelHandler {
            self.close()
        }
        
        source.resume()
        self.readSource = source
    }
}
