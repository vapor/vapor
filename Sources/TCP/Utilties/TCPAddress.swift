import COperatingSystem

/// A socket address
public struct TCPAddress {
    /// The raw underlying storage
    let storage: sockaddr_storage
    
    /// Creates a new socket address
    init(storage: sockaddr_storage) {
        self.storage = storage
    }
    
    /// Creates a new socket address
    init(storage: sockaddr) {
        var storage = storage
        
        self.storage = withUnsafePointer(to: &storage) { pointer in
            return pointer.withMemoryRebound(to: sockaddr_storage.self, capacity: 1) { storage in
                return storage.pointee
            }
        }
    }
    
    static func withSockaddrPointer<T>(
        do closure: ((UnsafeMutablePointer<sockaddr>) throws -> (T))
    ) rethrows -> (T, TCPAddress) {
        var addressStorage = sockaddr_storage()
        
        let other = try withUnsafeMutablePointer(to: &addressStorage) { pointer in
            return try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                return try closure(socketAddress)
            }
        }
        
        let address = TCPAddress(storage: addressStorage)
        
        return (other, address)
    }
}

extension TCPAddress: Equatable {
    /// Compares 2 addresses to be equal
    public static func ==(lhs: TCPAddress, rhs: TCPAddress) -> Bool {
        let lhs = lhs.storage
        let rhs = rhs.storage
        
        // They must have the same family
        guard lhs.ss_family == rhs.ss_family else {
            return false
        }
        
        switch numericCast(lhs.ss_family) as UInt32 {
        case numericCast(AF_INET):
            // If the family is IPv4, compare the 2 as IPv4
            return lhs.withIn_addr { lhs in
                return rhs.withIn_addr { rhs in
                    return memcmp(&lhs, &rhs, MemoryLayout<in6_addr>.size) == 0
                }
            }
        case numericCast(AF_INET6):
            // If the family is IPv6, compare the 2 as IPv6
            return lhs.withIn6_addr { lhs in
                return rhs.withIn6_addr { rhs in
                    return memcmp(&lhs, &rhs, MemoryLayout<in6_addr>.size) == 0
                }
            }
        default:
            // Impossible scenario
            fatalError()
        }
    }
    
}

extension TCPAddress {
    /// The remote peer's connection's port
    public var port: UInt16 {
        var copy = self.storage
        
        let val: UInt16
        
        switch numericCast(self.storage.ss_family) as UInt32 {
        case numericCast(AF_INET):
            // Extract the port from the struct cast as sockaddr_in
            val = withUnsafePointer(to: &copy) { pointer -> UInt16 in
                pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { pointer -> UInt16 in
                    return pointer.pointee.sin_port
                }
            }
        case numericCast(AF_INET6):
            // Extract the port from the struct cast as sockaddr_in6
            val = withUnsafePointer(to: &copy) { pointer -> UInt16 in
                pointer.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { pointer -> UInt16 in
                    return pointer.pointee.sin6_port
                }
            }
        default:
            // Impossible scenario
            fatalError()
        }
        
        return htons(val)
    }
    
    /// The remote's IP address
    public var remoteAddress: String {
        let stringData: UnsafeMutablePointer<Int8>
        let maxStringLength: socklen_t
        
        switch numericCast(self.storage.ss_family) as UInt32 {
        case numericCast(AF_INET):
            // Extract the remote IPv4 address
            maxStringLength = socklen_t(INET_ADDRSTRLEN)
            
            // Allocate an IPv4 address
            stringData = UnsafeMutablePointer<Int8>.allocate(capacity: numericCast(maxStringLength))
            
            _ = self.storage.withIn_addr { address in
                inet_ntop(numericCast(self.storage.ss_family), &address, stringData, maxStringLength)
            }
        case numericCast(AF_INET6):
            // Extract the remote IPv6 address
            
            // Allocate an IPv6 address
            maxStringLength = socklen_t(INET6_ADDRSTRLEN)
            stringData = UnsafeMutablePointer<Int8>.allocate(capacity: numericCast(maxStringLength))
            
            _ = self.storage.withIn6_addr { address in
                inet_ntop(numericCast(self.storage.ss_family), &address, stringData, maxStringLength)
            }
        default:
            // Impossible scenario
            fatalError()
        }
        
        defer {
            // Clean up
            stringData.deallocate(capacity: numericCast(maxStringLength))
        }
        
        // This cannot fail
        return String(validatingUTF8: stringData)!
    }
}

extension sockaddr_storage {
    // Accesses the sockaddr_storage as sockaddr_in
    fileprivate func withIn_addr<T>(call: ((inout in_addr)->(T))) -> T {
        var copy = self
        
        return withUnsafePointer(to: &copy) { pointer in
            return pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { pointer in
                var address = pointer.pointee.sin_addr
                
                return call(&address)
            }
        }
    }
    
    // Accesses the sockaddr_storage as sockaddr_in6
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

/// converts host byte order to network byte order
fileprivate func htons(_ value: UInt16) -> UInt16 {
    return (value << 8) &+ (value >> 8)
}
