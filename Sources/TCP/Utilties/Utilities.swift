import Foundation

#if os(Linux)
import COperatingSystem

// fix some constants on linux
let SOCK_STREAM = Int32(libc.SOCK_STREAM.rawValue)
let IPPROTO_TCP = Int32(libc.IPPROTO_TCP)
#endif
