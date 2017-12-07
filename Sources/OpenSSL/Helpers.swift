import Async
import Bits
import COpenSSL
import Dispatch

extension OpenSSLStream {
    /// Runs the SSL handshake, regardless of client or server
    func handshake(for ssl: UnsafeMutablePointer<SSL>, side: Side) -> Future<Void> {
        var accepted = false
        
        func retry() -> Int32 {
            if case .client = side {
                return SSL_connect(ssl)
            } else if !accepted {
                return SSL_accept(ssl)
            } else {
                return SSL_do_handshake(ssl)
            }
        }
        
        let promise = Promise<Void>()
        
        var result: Int32 = 0
        var code: Int32 = 0
        
        func attemptInstantiation() {
            repeat {
                result = retry()
                code = SSL_get_error(ssl, result)
            } while result == -1 && (
                code == SSL_ERROR_WANT_READ ||
                code == SSL_ERROR_WANT_WRITE ||
                code == SSL_ERROR_WANT_READ ||
                code == SSL_ERROR_WANT_CONNECT
            )
            
            if case .server = side, !accepted {
                accepted = true
                return attemptInstantiation()
            }
            
            if result == -1 {
                promise.fail(OpenSSLError(.sslError(result)))
            } else {
                promise.complete(())
            }
        }
        
        attemptInstantiation()
        
        return promise.future
    }
}
