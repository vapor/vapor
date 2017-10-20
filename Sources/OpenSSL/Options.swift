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
    typealias Trigger = ((UnsafeMutablePointer<SSL>, UnsafeMutablePointer<SSL_CTX>) throws -> (Void))
    
    var setupContext: ((UnsafeMutablePointer<SSL_CTX>) throws -> (Void))?
    var preHandshake: Trigger?
    var postHandshake: Trigger?
    
    public static func peerDomainName(_ hostname: String) -> SSLOption {
        return SSLOption(
            setupContext: nil,
            preHandshake: { ssl, _ in
                var hostname = [UInt8](hostname.utf8)
                SSL_ctrl(ssl, SSL_CTRL_SET_TLSEXT_HOSTNAME, Int(TLSEXT_NAMETYPE_host_name), &hostname)
            }, postHandshake: nil
        )
    }
    
    public static func certificate(atPath path: String) -> SSLOption {
        return SSLOption(
            setupContext: nil,
            preHandshake: { _, context in
                SSL_CTX_load_verify_locations(context, path, nil)
            },
            postHandshake: nil
        )
    }
    
    public static func alpn(protocols preferences: ALPNPreferences) -> SSLOption {
        return SSLOption(
            setupContext: { context in
                let protocolsBuffer = Array(preferences.protocols.map { proto in
                    return [UInt8(proto.utf8.count)] + proto.utf8
                }.joined())
                
                SSL_CTX_set_next_proto_select_cb(context, { (ssl, output, outputLength, input, inputLength, protocols) -> Int32 in
                    guard let input = input else {
                        return SSL_TLSEXT_ERR_NOACK
                    }
                    
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
            
//                SSL_CTX_set_alpn_protos(context, protocolsBuffer, UInt32(preferences.protocols.count))
            },
            preHandshake: nil,
            postHandshake: { ssl, context in
                let protocolPointer = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
                let protocolLengthPointer = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
                
                defer {
                    protocolPointer.deallocate(capacity: 1)
                    protocolLengthPointer.deallocate(capacity: 1)
                }
                
                SSL_get0_next_proto_negotiated(ssl, protocolPointer, protocolLengthPointer)
                
                if protocolPointer.pointee == nil {
                    SSL_get0_alpn_selected(ssl, protocolPointer, protocolLengthPointer)
                }
                
                let protoBuffer = UnsafeBufferPointer<UInt8>(start: protocolPointer.pointee, count: numericCast(protocolLengthPointer.pointee))
                
                let proto = String(bytes: protoBuffer, encoding: .utf8) ?? ""
                
                guard preferences.protocols.contains(proto) else {
                    throw Error(.invalidALPNProtocol)
                }
            }
        )
    }
}
