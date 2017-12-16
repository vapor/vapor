import Foundation

extension Int {
    public static var maxTCPPacketSize: Int {
        return 65535
    }
}

#if os(Linux)
import COperatingSystem

// fix some constants on linux
let SOCK_STREAM = Int32(COperatingSystem.SOCK_STREAM.rawValue)
let IPPROTO_TCP = Int32(COperatingSystem.IPPROTO_TCP)
#endif
