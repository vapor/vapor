/// Errors thrown when a ``Server`` fails to start.
@nonexhaustive
public enum ServerError: Error, Equatable, CustomStringConvertible {
    /// Another process, or another server in this one, is already listening on the address.
    case addressInUse(host: String, port: Int)

    public var description: String {
        switch self {
        case .addressInUse(let host, let port):
            let address = host.contains(":") ? "[\(host)]:\(port)" : "\(host):\(port)"
            return "Cannot start the server: \(address) is already in use."
        }
    }
}
