import libc

extension sockaddr_storage {
    /// The remote peer's connection's port
    public var port: UInt16 {
        var copy = self
        
        let val: UInt16
        
        switch self.ss_family {
        case UInt8(AF_INET):
            val = withUnsafePointer(to: &copy) { pointer -> UInt16 in
                pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { pointer -> UInt16 in
                    return pointer.pointee.sin_port
                }
            }
        case UInt8(AF_INET6):
            val = withUnsafePointer(to: &copy) { pointer -> UInt16 in
                pointer.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { pointer -> UInt16 in
                    return pointer.pointee.sin6_port
                }
            }
        default:
            fatalError()
        }
        
        return htons(val)
    }
    
    /// The remote's IP address
    public var remoteAddress: String {
        var copy = self
        
        let stringData: UnsafeMutablePointer<Int8>
        let maxStringLength: socklen_t
        
        switch self.ss_family {
        case UInt8(AF_INET):
            maxStringLength = socklen_t(INET_ADDRSTRLEN)
            stringData = UnsafeMutablePointer<Int8>.allocate(capacity: numericCast(maxStringLength))
            
            _ = withUnsafePointer(to: &copy) { pointer in
                pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { pointer in
                    var address = pointer.pointee.sin_addr
                    inet_ntop(numericCast(self.ss_family), &address, stringData, maxStringLength)
                }
            }
        case UInt8(AF_INET6):
            maxStringLength = socklen_t(INET6_ADDRSTRLEN)
            stringData = UnsafeMutablePointer<Int8>.allocate(capacity: numericCast(maxStringLength))
            
            _ = withUnsafePointer(to: &copy) { pointer in
                pointer.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { pointer in
                    var address = pointer.pointee.sin6_addr
                    inet_ntop(numericCast(self.ss_family), &address, stringData, maxStringLength)
                }
            }
        default:
            fatalError()
        }
        
        defer {
            stringData.deallocate(capacity: numericCast(maxStringLength))
        }
        
        // This cannot fail
        return String(validatingUTF8: stringData)!
    }
}

fileprivate func htons(_ value: UInt16) -> UInt16 {
    return (value << 8) + (value >> 8)
}
