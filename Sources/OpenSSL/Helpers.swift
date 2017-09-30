import Bits
import CTLS
import Dispatch

extension SSLStream {
    /// Runs the SSL handshake, regardless of client or server
    func handshake(for ssl: UnsafeMutablePointer<SSL>) throws {
        var result: Int32
        var code: Int32

//        repeat {
//            result = SSL_connect(ssl)
//            code = SSL_get_error(ssl, result)
//        } while result == -1 && (code == SSL_ERROR_WANT_READ || code == SSL_ERROR_WANT_WRITE)
//        
//        guard result == 1 else {
//            throw Error.sslError(result)
//        }
        
        repeat {
            result = SSL_connect(ssl)
            code = SSL_get_error(ssl, result)
        } while result == -1 && (code == SSL_ERROR_WANT_READ || code == SSL_ERROR_WANT_WRITE)
        
        guard result == 1 else {
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
    public func setCertificate(toFileAt certificatePath: String) throws {
        if let context = context {
            SSL_CTX_load_verify_locations(context, certificatePath, nil)
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
