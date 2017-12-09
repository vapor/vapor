import Async
import Bits
import Foundation
import Security

/// Internal helper that asserts the success of an operation
func assert(status: OSStatus) throws {
    guard status == 0 else {
        throw AppleSSLError(.sslError(status))
    }
}

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
    func setCertificate(to certificate: String, for context: SSLContext) throws {
        // Load the certificate
        guard let certificateData = FileManager.default.contents(atPath: certificate) else {
            throw AppleSSLError(.certificateNotFound)
        }
        
        // Process the certificate into one usable by the Security library
        guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
            throw AppleSSLError(.invalidCertificate)
        }
        
        var ref: SecIdentity?
        
        // Applies the certificate
        try assert(status: SecIdentityCreateWithCertificate(nil, certificate, &ref))
        try assert(status: SSLSetCertificate(context, [ref as Any, certificate] as CFArray))
    }
}
