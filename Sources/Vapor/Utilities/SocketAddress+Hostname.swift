import enum NIO.SocketAddress

extension SocketAddress {
    /// Returns the hostname for this `SocketAddress` if one exists.
    public var hostname: String? {
        switch self {
        case .unixDomainSocket: return nil
        case .v4(let v4): return v4.host
        case .v6(let v6): return v6.host
        }
    }
}
