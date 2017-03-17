import TLS

/// Available security layers
public enum SecurityLayer {
    case none
    case tls(TLS.Context)
}
