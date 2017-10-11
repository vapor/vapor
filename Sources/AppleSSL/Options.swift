import Security
import Foundation

/// SSLOptions are used for configuring the SSL connection
public struct SSLOption {
    /// A closure to be executed when applying the option
    internal var apply: ((SSLContext) throws -> ())
    
    /// Internal helper that asserts the success of an operation
    fileprivate static func assert(status: OSStatus) throws {
        guard status == 0 else {
            throw Error(.sslError(status))
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
    public static func alpn(protocols: [String]) -> SSLOption {
        return SSLOption { context in
            if #available(OSX 10.13, *) {
                var protocols = protocols as CFArray
                try assert(status: SSLSetALPNProtocols(context, protocols))
            } else {
                throw Error(.notSupported)
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
                throw Error(.certificateNotFound)
            }
            
            // Process the certificate into one usable by the Security library
            guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
                throw Error(.invalidCertificate)
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
                throw Error(.certificateNotFound)
            }
            
            // Process the certificate into one usable by the Security library
            guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
                throw Error(.invalidCertificate)
            }
            
            // Trust the certificate
            try assert(status: SSLSetCertificateAuthorities(context, certificate, false))
        }
    }
}
