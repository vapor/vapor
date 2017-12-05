import Security
import Foundation

public final class ALPNPreferences: ExpressibleByArrayLiteral {
    var protocols: [String]
    
    public internal(set) var selectedProtocol: String? = nil
    
    public init(arrayLiteral elements: String...) {
        self.protocols = elements
    }
    
    public init(array: [String]) {
        self.protocols = array
    }
}

/// SSLOptions are used for configuring the SSL connection
public struct SSLOption {
    /// A closure to be executed when applying the option
    internal var apply: ((SSLContext) throws -> ())
    
    /// Internal helper that asserts the success of an operation
    fileprivate static func assert(status: OSStatus) throws {
        guard status == 0 else {
            throw AppleSSLError(.sslError(status))
        }
    }
    
    /// Sets the SNI peer domain name to the provided hostname
    public static func peerDomainName(_ hostname: String) -> SSLOption {
        return SSLOption { context in
            var hostname = [Int8](hostname.utf8.map { Int8($0) })
            try assert(status: SSLSetPeerDomainName(context, &hostname, hostname.count))
        }
    }
    
    /// Sends the Application Layer Protocol Negotiation supported protocols
    public static func alpn(protocols: ALPNPreferences) -> SSLOption {
        return SSLOption { context in
            print("This may not work, apple needs to fix a bug related to ALPN")
            
            if #available(OSX 10.13, *) {
//                let protocols = protocols.protocols as CFArray
//                try assert(status: SSLSetALPNProtocols(context, protocols))
            } else {
                print("This may not work, you need to upgrade to macOS 10.13")
            }
        }
    }
    
    /// Sets the minimum SSL Protocol version
    public static func minimumVersion(_ protocol: SSLProtocol) -> SSLOption {
        return SSLOption { context in
            try assert(status: SSLSetProtocolVersionMin(context, `protocol`))
        }
    }
    
    /// Sets the maximum SSL Protocol version
    public static func maximumVersion(_ protocol: SSLProtocol) -> SSLOption {
        return SSLOption { context in
            try assert(status: SSLSetProtocolVersionMax(context, `protocol`))
        }
    }
    
    /// Uses this certificate as it's own
    public static func useCertificate(atPath path: String) -> SSLOption {
        return SSLOption { context in
            // Load the certificate
            guard let certificateData = FileManager.default.contents(atPath: path) else {
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
    
    /// Adds a certificate authority as a trusted authority for this connection
    public static func certificateAuthority(atPath path: String) -> SSLOption {
        return SSLOption { context in
            // Load the certificate
            guard let certificateData = FileManager.default.contents(atPath: path) else {
                throw AppleSSLError(.certificateNotFound)
            }
            
            // Process the certificate into one usable by the Security library
            guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
                throw AppleSSLError(.invalidCertificate)
            }
            
            // Trust the certificate
            try assert(status: SSLSetCertificateAuthorities(context, certificate, false))
        }
    }
}
