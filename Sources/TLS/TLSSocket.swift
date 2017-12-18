import Async
import Bits

public protocol TLSSocket: Socket {}

/// MARK: ALPN

public protocol ALPNSupporting: TLSSocket {
    var ALPNprotocols: [String] { get set }
    var selectedProtocol: String? { get }
}
