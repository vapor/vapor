import Hummingbird
#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

typealias ServerSocket = Hummingbird.ServerSocket
typealias Socket = Hummingbird.Socket

extension Hummingbird.Socket: HTTPStream { }

extension Hummingbird.ServerSocket: HTTPListenerStream {
    convenience init(address: String?, port: Int) throws {
        try self.init(address: address, port: String(port))
    }

    func accept(max connectionCount: Int = Int(SOMAXCONN), handler: ((HTTPStream) -> Void)) throws {
        try accept(maximumConsecutiveFailures: connectionCount, connectionHandler: handler)
    }

    func listen() throws {
        try listen(pendingConnectionBacklog: 100)
    }

}

extension SocketError: HTTPStreamError {
    /// `true` if the case is `.connectionClosedByPeer` or failed w/ code 54
    public var isClosedByPeer: Bool {
        switch self {
        // Code 54 is closed by peer
        case .receiveFailed(code: let code, message: _) where code == 54:
            return true
        case .connectionClosedByPeer:
            return true
        default:
            return false
        }
    }
}
