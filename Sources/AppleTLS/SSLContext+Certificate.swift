import Async
import Bits
import Foundation
import Security

extension SSLContext {
    /// Sets the certificate regardless of Client/Server.
    ///
    /// This is mandatory for SSL Servers to work. Optional for Clients.
    ///
    /// The certificate entered is the public key. The private key will be retreived from the keychain.
    ///
    /// You need to register the `.p12` file to the `login` keychain. The `.p12` must be associated with the public key certificate defined here.
    ///
    /// https://www.sslshopper.com/article-most-common-openssl-commands.html
    func setCertificate(to certificatePath: String) throws {
        // Load the certificate
        guard let certificateData = FileManager.default.contents(atPath: certificatePath) else {
            throw AppleTLSError(identifier: "certificateNotFound", reason: "No certificate was found at path \(certificatePath)")
        }
        
        // Process the certificate into one usable by the Security library
        guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
            throw AppleTLSError(identifier: "invalidCertificate", reason: "Invalid certificate at path \(certificatePath)")
        }
        
        var ref: SecIdentity?
        
        // Applies the certificate
        var status = SecIdentityCreateWithCertificate(nil, certificate, &ref)
        guard status == 0 else {
            throw AppleTLSError.secError(status)
        }
        status = SSLSetCertificate(self, [ref as Any, certificate] as CFArray)
        guard status == 0 else {
            throw AppleTLSError.secError(status)
        }
    }
}
