import HTTP

/// Servers are capable of binding to an address
/// and subsequently responding to requests sent
/// to that address.
public protocol HTTPServer {
    func start(with responder: Responder) throws
}
