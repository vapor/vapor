import libc

extension sockaddr_storage {
    /// The remote peer's connection's port
    public var port: UInt16 {
        var copy = self
        
        let val: UInt16
        
        switch numericCast(self.ss_family) as UInt32 {
        case numericCast(AF_INET):
            val = withUnsafePointer(to: &copy) { pointer -> UInt16 in
                pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { pointer -> UInt16 in
                    return pointer.pointee.sin_port
                }
            }
        case numericCast(AF_INET6):
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
        let stringData: UnsafeMutablePointer<Int8>
        let maxStringLength: socklen_t
        
        switch numericCast(self.ss_family) as UInt32 {
        case numericCast(AF_INET):
            maxStringLength = socklen_t(INET_ADDRSTRLEN)
            stringData = UnsafeMutablePointer<Int8>.allocate(capacity: numericCast(maxStringLength))
            
            _ = self.withIn_addr { address in
                inet_ntop(numericCast(self.ss_family), &address, stringData, maxStringLength)
            }
        case numericCast(AF_INET6):
            maxStringLength = socklen_t(INET6_ADDRSTRLEN)
            stringData = UnsafeMutablePointer<Int8>.allocate(capacity: numericCast(maxStringLength))
            
            _ = self.withIn6_addr { address in
                inet_ntop(numericCast(self.ss_family), &address, stringData, maxStringLength)
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
    
    fileprivate func withIn_addr<T>(call: ((inout in_addr)->(T))) -> T {
        var copy = self
        
        return withUnsafePointer(to: &copy) { pointer in
            return pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { pointer in
                var address = pointer.pointee.sin_addr
                
                return call(&address)
            }
        }
    }
    
    fileprivate func withIn6_addr<T>(call: ((inout in6_addr)->(T))) -> T {
        var copy = self
        
        return withUnsafePointer(to: &copy) { pointer in
            return pointer.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { pointer in
                var address = pointer.pointee.sin6_addr
                
                return call(&address)
            }
        }
    }
}

extension sockaddr_storage: Equatable {
    public static func ==(lhs: sockaddr_storage, rhs: sockaddr_storage) -> Bool {
        guard lhs.ss_family == rhs.ss_family else {
            return false
        }
        
        switch numericCast(lhs.ss_family) as UInt32 {
        case numericCast(AF_INET):
            return lhs.withIn_addr { lhs in
                return rhs.withIn_addr { rhs in
                    return memcmp(&lhs, &rhs, MemoryLayout<in6_addr>.size) == 0
                }
            }
        case numericCast(AF_INET6):
            return lhs.withIn6_addr { lhs in
                return rhs.withIn6_addr { rhs in
                    return memcmp(&lhs, &rhs, MemoryLayout<in6_addr>.size) == 0
                }
            }
        default:
            fatalError()
        }
    }
}

fileprivate func htons(_ value: UInt16) -> UInt16 {
    return (value << 8) + (value >> 8)
}
