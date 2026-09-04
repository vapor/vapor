public struct ServerConfiguration: Sendable {
    public var address: BindAddress

    /// The TLS configuration for the server, or `nil` to serve over plaintext HTTP.
    public var tlsConfiguration: TLSConfiguration?

    /// The HTTP versions the server accepts. Defaults to HTTP/1.1 only; adding HTTP/2 requires a ``tlsConfiguration``.
    public var httpVersions: Set<HTTPVersion>

    /// How many file content hashes to keep for advanced ETag comparison.
    ///
    /// Only files served with `advancedETagComparison` enabled are hashed, and each entry is just a
    /// path and a digest — raise this when serving more such files than the default holds, so their
    /// hashes aren't evicted before they're used again. A new capacity applies from the next hash
    /// cached, so lowering it doesn't discard entries already held.
    public var eTagHashCacheCapacity: UInt

    /// How many bytes of an *unread* request body the server will drain to keep the connection alive.
    /// Past this the drain stops and the connection is closed instead of reading on — a DoS guard.
    /// Defaults to 16 KB.
    ///
    /// The budget applies only to the bytes this drain reads, not to what the handler already
    /// consumed: a handler that deliberately read a large body and left a small remainder still gets
    /// its connection reused, while an unconsumed body larger than this is drained up to the budget
    /// and then the connection is closed.
    public var maxDrainBytes: Int

    public init(
        address: BindAddress = .hostname(),
        tlsConfiguration: TLSConfiguration? = nil,
        httpVersions: Set<HTTPVersion> = [.http1_1],
        eTagHashCacheCapacity: UInt = 1024,
        maxDrainBytes: Int = 1 << 14
    ) {
        self.address = address
        self.tlsConfiguration = tlsConfiguration
        self.httpVersions = httpVersions
        self.eTagHashCacheCapacity = eTagHashCacheCapacity
        self.maxDrainBytes = maxDrainBytes
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
