import Async
import Bits
import Foundation
import Security

extension SSLStream {
    /// Runs the SSL handshake, regardless of client or server
    func handshake(for context: SSLContext) throws -> Future<Void> {
        var result = SSLHandshake(context)
        
        // If the success is immediate
        if result == errSecSuccess || result == errSSLPeerAuthCompleted {
            return Future(())
        }
        
        // Otherwise set up a readsource
        let readSource = DispatchSource.makeReadSource(fileDescriptor: self.descriptor, queue: self.queue)
        let promise = Promise<Void>()
        
        // Listen for input
        readSource.setEventHandler {
            // On input, continue the handshake
            result = SSLHandshake(context)
            
            if result == errSSLWouldBlock {
                return
            }
            
            // If it's not blocking and not a success, it's an error
            guard result == errSecSuccess || result == errSSLPeerAuthCompleted else {
                readSource.cancel()
                promise.fail(AppleSSLError(.sslError(result)))
                return
            }
            
            readSource.cancel()
            promise.complete(())
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
    
    /// Sets the certificate regardless of Client/Server.
    ///
    /// This is mandatory for SSL Servers to work. Optional for Clients.
    ///
    /// The certificate entered is the public key. The private key will be retreived from the keychain.
    ///
    /// You need to register the `.p12` file to the `login` keychain. The `.p12` must be associated with the public key certificate defined here.
    ///
    /// https://www.sslshopper.com/article-most-common-openssl-commands.html
    public func setCertificate(to certificate: Data, for context: SSLContext) throws {
        guard let certificate = SecCertificateCreateWithData(nil, certificate as CFData) else {
            throw AppleSSLError(.invalidCertificate)
        }
        
        var ref: SecIdentity?
        
        var error = SecIdentityCreateWithCertificate(nil, certificate, &ref)
        
        guard error == errSecSuccess else {
            throw AppleSSLError(.invalidCertificate)
        }
        
        error = SSLSetCertificate(context, [ref as Any, certificate] as CFArray)
        
        guard error == errSecSuccess else {
            throw AppleSSLError(.invalidCertificate)
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
            if let context = self.context {
                SSLClose(context)
            }
            
            self.close()
        }
        
        source.resume()
        self.readSource = source
    }
}
