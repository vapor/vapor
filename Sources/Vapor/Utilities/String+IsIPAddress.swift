import Foundation
#if canImport(CNIOLinux)
import CNIOLinux
#endif
#if canImport(Android)
import Android
#endif

extension String {
    func isIPAddress() -> Bool {
        // We need some scratch space to let inet_pton write into.
        var ipv4Addr = in_addr()
        var ipv6Addr = in6_addr()
        
        return self.withCString { ptr in
            return inet_pton(AF_INET, ptr, &ipv4Addr) == 1 ||
                inet_pton(AF_INET6, ptr, &ipv6Addr) == 1
        }
    }
}
