import HTTP
import Transport
import URI
import TLS

public protocol ClientProtocol: Responder {
    init(
        hostname: String,
        port: Port,
        _ securityLayer: SecurityLayer
    ) throws
}
