import Async
import Bits
import Foundation

/// A stream of incoming and outgoing strings between 2 parties over WebSockets
///
/// [Learn More →](https://docs.vapor.codes/3.0/websocket/text-stream/)
final class StringStream: ProtocolTransformationStream {
    typealias Input = Frame
    typealias Output = String
    
    /// The upstream output stream supplying strings
    private var websocket: WebSocket
    
    /// The downstream, listening for strings
    internal var downstream: AnyInputStream<Output>?
    
    /// The upstream output stream supplying redis data
    internal var upstream: ConnectionContext?
    
    /// Remaining downstream demand
    internal var downstreamDemand: UInt
    
    var backlog: [String]
    
    var consumedBacklog: Int
    
    var state: ProtocolParserState
    
    func transform(_ input: Frame) throws {
        let data = Data(buffer: input.buffer)
        
        guard let string = String(data: data, encoding: .utf8) else {
            throw WebSocketError(.invalidSubprotocol)
        }
        
        flush(string)
    }
    
    /// Creates a new TextStream that has yet to be linked up with other streams
    init(for websocket: WebSocket) {
        self.websocket = websocket
        self.backlog = []
        self.downstreamDemand = 0
        self.consumedBacklog = 0
        self.state = .ready
    }
}

extension WebSocket {
    /// Sends a string to the server
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/websocket/text-stream/)
    public func send(_ string: String) {
        Data(string.utf8).withByteBuffer { buffer in
            let mask: [UInt8]?
            
            if self.mode == .client {
                mask = randomMask()
            }
            
            let frame = Frame(op: .text, payload: buffer, mask: mask)
            
            self.backlog.append(frame)
        }
    }

    /// Drains the TextStream into this closure.
    ///
    /// Any previously listening closures will be overridden
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/websocket/text-stream/)
    public func onText(_ closure: @escaping ((String) -> ())) -> AnyInputStream<String> {
        self.stringOutputStream
    }
}
