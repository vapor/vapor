import Async
import Bits
import Foundation
import Security

extension AppleSSLStream {
    /// Runs the SSL handshake, regardless of client or server
    func handshake(for context: SSLContext) -> Future<Void> {
        var result = SSLHandshake(context)
        
        // If the success is immediate
        if result == errSecSuccess || result == errSSLPeerAuthCompleted {
            return Future(())
        }
        
        // Otherwise set up a readsource
        let readSource = DispatchSource.makeReadSource(fileDescriptor: self.socket.descriptor, queue: self.queue)
        let promise = Promise<DispatchSourceRead>()
        
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
            promise.complete(readSource)
        }
        
        // Now that the async stuff's et up, let's start your engines
        readSource.resume()
        
        return promise.future.map { _ in }
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
    func setCertificate(to certificate: Data, for context: SSLContext) throws {
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
}
