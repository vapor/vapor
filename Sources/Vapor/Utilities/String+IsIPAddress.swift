#if canImport(Glibc)
import Glibc
#if canImport(CNIOLinux)
/// Until the Glibc Swift module is fixed, it's possible that the system header files on which the helpers in this file
/// rely are misattributed to another module in a very parallel build, in this case CNIOLinux, which also imports
/// `in.h`, which defines `in_addr` and `in6_addr`.
///
/// See: https://github.com/swiftlang/swift/issues/85427
import CNIOLinux
#endif
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#else
import Darwin
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
