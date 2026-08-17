public struct ServerConfiguration: Sendable {
    public var address: BindAddress

    /// The TLS configuration for the server, or `nil` to serve over plaintext HTTP.
    public var tlsConfiguration: TLSConfiguration?

    /// The HTTP versions the server accepts. Defaults to HTTP/1.1 only; adding HTTP/2 requires a ``tlsConfiguration``.
    public var httpVersions: Set<HTTPVersion>

    public init(
        address: BindAddress = .hostname(),
        tlsConfiguration: TLSConfiguration? = nil,
        httpVersions: Set<HTTPVersion> = [.http1_1]
    ) {
        self.address = address
        self.tlsConfiguration = tlsConfiguration
        self.httpVersions = httpVersions
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

    /// Whether the server is configured to serve over TLS.
    public var isTLSEnabled: Bool {
        tlsConfiguration != nil
    }

    /// A human-readable description of the configured address. Used in log messages when starting server.
    var addressDescription: String {
        let scheme = isTLSEnabled ? "https" : "http"
        switch address {
        case .hostname(let hostname, let port):
            return "\(scheme)://\(hostname):\(port)"
        case .unixDomainSocket(let socketPath):
            return "\(scheme)+unix: \(socketPath)"
        }
    }
}
