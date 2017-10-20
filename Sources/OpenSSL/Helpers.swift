import Async
import Bits
import COpenSSL
import Dispatch

extension SSLStream {
    /// Runs the SSL handshake, regardless of client or server
    func handshake(for ssl: UnsafeMutablePointer<SSL>, side: Side) throws -> Future<Void> {
        var accepted: Bool
        
        if case .client = side {
            accepted = true
        } else {
            accepted = false
        }
        
        func retry() -> Int32 {
            if case .client = side {
                return SSL_connect(ssl)
            } else if !accepted {
                return SSL_accept(ssl)
            } else {
                return SSL_do_handshake(ssl)
            }
        }
        
        // Otherwise set up a readsource
        let readSource = DispatchSource.makeReadSource(fileDescriptor: self.descriptor, queue: self.queue)
        let writeSource = DispatchSource.makeWriteSource(fileDescriptor: self.descriptor, queue: self.queue)
        
        var reading = true
        var writing = false
        
        let promise = Promise<Void>()
        
        func process(result: Int32) {
            let code = SSL_get_error(ssl, result)
            
            if reading {
                reading = false
                readSource.suspend()
            }
            
            if writing {
                writing = false
                writeSource.suspend()
            }
            
            if result == -1 {
                if code == SSL_ERROR_WANT_READ {
                    reading = true
                    readSource.resume()
                    return
                }
                
                if code == SSL_ERROR_WANT_WRITE {
                    writing = true
                    writeSource.resume()
                    return
                }
                
                if code == SSL_ERROR_WANT_CONNECT {
                    process(result: retry())
                    return
                }
                
                readSource.cancel()
                ERR_print_errors_fp(stdout)
                promise.fail(Error(.sslError(result)))
                return
            }
            
            if accepted {
                readSource.cancel()
                writeSource.cancel()
                promise.complete(())
            } else {
                accepted = true
                process(result: retry())
            }
        }
        
        func tryAgain() {
            // On input, continue the handshake
            process(result: retry())
        }
        
        readSource.setEventHandler(handler: tryAgain)
        
        tryAgain()
        
        let future = promise.future
        
        future.addAwaiter { _ in
            if reading {
                readSource.cancel()
            }
            
            if writing {
                writeSource.cancel()
            }
            
            self.readSource = nil
            self.writeSource = nil
        }
        
        self.readSource = readSource
        self.writeSource = writeSource
        
        return future
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
            throw Error(.noSSLContext)
        }
        
        SSL_CTX_use_certificate_file(context, certificatePath, SSL_FILETYPE_PEM)
        
        var error = SSL_CTX_use_certificate_file(context, certificatePath, SSL_FILETYPE_PEM)
        
        guard error > 0 else {
            throw Error(.sslError(error))
        }
        
        error = SSL_CTX_use_PrivateKey_file(context, keyPath, SSL_FILETYPE_PEM)
        
        guard error > 0 else {
            throw Error(.sslError(error))
        }
    }
    
    /// Starts receiving data from the client, reads on the provided queue
    public func start() {
        let readSource = DispatchSource.makeReadSource(
            fileDescriptor: self.descriptor,
            queue: self.queue
        )
        
        readSource.setEventHandler {
            let read: Int
            do {
                read = try self.read(into: self.outputBuffer)
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
        
        readSource.setCancelHandler {
            self.close()
        }
        
        readSource.resume()
        self.readSource = readSource
        
        let writeSource = DispatchSource.makeWriteSource(fileDescriptor: descriptor, queue: queue)
        
        writeSource.setEventHandler {
            guard self.writeQueue.count > 0 else {
                writeSource.suspend()
                return
            }
            
            let data = self.writeQueue[0]
            
            data.withUnsafeBytes { (pointer: BytesPointer) in
                let buffer = UnsafeBufferPointer(start: pointer, count: data.count)
                
                do {
                    try self.write(from: buffer)
                    _ = self.writeQueue.removeFirst()
                } catch {
                    self.errorStream?(error)
                }
            }
            
            guard self.writeQueue.count > 0 else {
                writeSource.suspend()
                return
            }
        }
        
        self.writeSource = writeSource
    }
}
