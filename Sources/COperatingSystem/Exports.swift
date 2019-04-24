#if os(Linux)
@_exported import Glibc
#else
@_exported import Darwin.C
#endif
