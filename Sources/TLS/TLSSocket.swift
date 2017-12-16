import Async
import Bits

public protocol TLSSocket: DispatchSocket {
    func read(max: Int, into buffer: MutableByteBuffer) throws -> Int
    func write(max: Int, from buffer: ByteBuffer) throws -> Int
    func close()
}

/// MARK: ALPN

public protocol ALPNSupporting: TLSSocket {
    var ALPNprotocols: [String] { get set }
    var selectedProtocol: String? { get }
}
