import TLS

public enum SecurityLayer {
    case none
    case tls(TLS.Context)
}
