import Async
import Bits
import Foundation
import Security

extension AppleSSLStream {
    /// Runs the SSL handshake, regardless of client or server
    func handshake() {
        let result = SSLHandshake(context)
        
        // If the success is immediate
        if result == errSecSuccess {
            self.connected.complete()
            return
        }
        
        guard result == errSSLWouldBlock else {
            self.connected.fail(AppleSSLError(.sslError(result)))
            self.close()
            return
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
