import Async
import Bits

public protocol TLSSocket: DispatchSocket {}

/// MARK: ALPN

public protocol ALPNSupporting: TLSSocket {
    var ALPNprotocols: [String] { get set }
    var selectedProtocol: String? { get }
}
