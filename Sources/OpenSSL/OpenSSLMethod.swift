import COpenSSL

public enum OpenSSLSide {
    case client
    case server(certificate: String, key: String)
}

public enum OpenSSLMethod {
    case ssl23
    case tls1_0
    case tls1_1
    case tls1_2

    func method(side: OpenSSLSide) -> UnsafePointer<SSL_METHOD> {
        switch side {
        case .client:
            switch self {
            case .ssl23: return SSLv23_client_method()
            case .tls1_0: return TLSv1_client_method()
            case .tls1_1: return TLSv1_1_client_method()
            case .tls1_2: return TLSv1_2_client_method()
            }
        case .server(_, _):
            switch self {
            case .ssl23: return SSLv23_server_method()
            case .tls1_0: return TLSv1_server_method()
            case .tls1_1: return TLSv1_1_server_method()
            case .tls1_2: return TLSv1_2_server_method()
            }
        }
    }
}

public enum OpenSSLSettings {
    internal static var initialized: Bool = {
        SSL_library_init()
        SSL_load_error_strings()
        OPENSSL_config(nil)
        OPENSSL_add_all_algorithms_conf()
        return true
    }()
}
