import HTTP

/// Servers are capable of binding to an address
/// and subsequently responding to requests sent
/// to that address.
public protocol Server {
    func start() throws
}
