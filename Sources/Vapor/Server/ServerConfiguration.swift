public struct ServerConfiguration: Sendable {
    public var address: BindAddress

    public init(address: BindAddress = .hostname()) {
        self.address = address
    }

    /// Host name the server will bind to.
    public var hostname: String? {
        get {
            switch address {
            case .hostname(let hostname, _):
                return hostname
            default:
                return nil
            }
        }
        set {
            if let newValue {
                switch address {
                case .hostname(_, let port):
                    address = .hostname(newValue, port: port)
                default:
                    address = .hostname(newValue)
                }
            }
        }
    }

    /// Port the server will bind to.
    public var port: Int? {
        get {
            switch address {
            case .hostname(_, let port):
                port
            default:
                nil
            }
        }
        set {
            if let newValue {
                switch address {
                case .hostname(let hostname, _):
                    address = .hostname(hostname, port: newValue)
                default:
                    address = .hostname(port: newValue)
                }
            }
        }
    }

    /// A human-readable description of the configured address. Used in log messages when starting server.
    var addressDescription: String {
        #warning("Bring back")
//            let scheme = tlsConfiguration == nil ? "http" : "https"
        let scheme = "https"
        switch address {
        case .hostname(let hostname, let port):
            return "\(scheme)://\(hostname):\(port)"
        case .unixDomainSocket(let socketPath):
            return "\(scheme)+unix: \(socketPath)"
        }
    }
}
