import libc
import COpenSSL

public final class ALPNPreferences: ExpressibleByArrayLiteral {
    var protocols: [String]
    
    public init(arrayLiteral elements: String...) {
        self.protocols = elements
    }
    
    public init(array: [String]) {
        self.protocols = array
    }
}

public struct SSLOption {
    var apply: ((UnsafeMutablePointer<SSL>, UnsafeMutablePointer<SSL_CTX>) throws -> (Void))
    
    public static func peerDomainName(_ hostname: String) -> SSLOption {
        return SSLOption { ssl, _ in
            var hostname = [UInt8](hostname.utf8)
            SSL_ctrl(ssl, SSL_CTRL_SET_TLSEXT_HOSTNAME, Int(TLSEXT_NAMETYPE_host_name), &hostname)
        }
    }
    
    public static func certificate(atPath path: String) -> SSLOption {
        return SSLOption { _, context in
            SSL_CTX_load_verify_locations(context, path, nil)
        }
    }
    
    public static func alpn(protocols preferences: ALPNPreferences) -> SSLOption {
        return SSLOption { _, context in
            let protocolsBuffer = Array(preferences.protocols.map { proto in
                return [UInt8(proto.utf8.count)] + proto.utf8
            }.joined())
            
            SSL_CTX_set_next_proto_select_cb(context, { (ssl, output, outputLength, input, inputLength, protocols) -> Int32 in
                guard let input = input else {
                    return SSL_TLSEXT_ERR_NOACK
                }
                
                //TODO: let preferences = protocols!.assumingMemoryBound(to: ALPNPreferences.self).pointee
                var available = [String]()
                var pointers = [UnsafePointer<UInt8>]()
                var lengths = [Int]()
                
                var base = 0
                
                while base < inputLength {
                    let length: Int = numericCast(input[base])
                    
                    guard base &+ length < inputLength else {
                        return SSL_TLSEXT_ERR_NOACK
                    }
                    
                    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
                    
                    memcpy(buffer, input.advanced(by: base &+ 1), length)
                    
                    guard let proto = String(bytesNoCopy: buffer, length: length, encoding: .utf8, freeWhenDone: true) else {
                        buffer.deallocate(capacity: length)
                        return SSL_TLSEXT_ERR_NOACK
                    }
                    
                    available.append(proto)
                    pointers.append(input.advanced(by: base &+ 1))
                    lengths.append(length)
                    
                    base = base &+ 1 &+ length
                }
                
                for preference in ["h2", "http/1.1"] {
                    guard let index = available.index(of: preference) else {
                        continue
                    }
                    
                    output?.pointee = UnsafeMutablePointer(mutating: pointers[index])
                    outputLength?.pointee = numericCast(lengths[index])
                    
                    // select preference
                    return SSL_TLSEXT_ERR_OK
                }
                
                return SSL_TLSEXT_ERR_NOACK
            }, nil)
            
            SSL_CTX_set_alpn_protos(context, protocolsBuffer, UInt32(preferences.protocols.count))
        }
    }
}
