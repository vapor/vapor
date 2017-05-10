import TLS

/// Available security layers
public enum SecurityLayer {
    case none
    case tls(TLS.Context)
}


extension String {
    var port: Port {
        return isSecure ? 443 : 80
    }
}
