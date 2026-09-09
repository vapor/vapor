import NIOHTTPServer

extension SocketAddress {
    /// Converts an address reported by the underlying HTTP server
#warning("Need to handle UNIX sockets when HTTP server supports it")
    init?(_ address: NIOHTTPServer.SocketAddress) {
        if let ipv4 = address.ipv4 {
            self = .ipv4(host: ipv4.host, port: ipv4.port)
        } else if let ipv6 = address.ipv6 {
            self = .ipv6(host: ipv6.host, port: ipv6.port)
        } else {
            return nil
        }
    }
}
