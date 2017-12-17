import Async
import Bits

/// A stream of incoming and outgoing strings between 2 parties over WebSockets
///
/// [Learn More →](https://docs.vapor.codes/3.0/websocket/text-stream/)
final class StringStream: Stream, ConnectionContext {
    typealias Input = String
    typealias Output = String
    
    /// Returns whether to add mask a mask to this message
    var masking: Bool
    
    /// An array, for when a single TCP message has > 1 entity
    var backlog: [String]
    
    /// The upstream output stream supplying strings
    private var upstream: ConnectionContext
    
    /// The downstream, listening for String input
    private var downstream: AnyInputStream<String>?
    
    /// Remaining downstream demand
    private var downstreamDemand: UInt
    
    /// Current state
    private var state: WebSocketStreamState
    
    /// Creates a new TextStream that has yet to be linked up with other streams
    init(writingTo upstream: Connection, mode: WebSocketMode) {
        self.masking = mode.masking
        self.upstream = upstream
        self.state = .ready
    }
    
    public func input(_ event: InputEvent<String>) {
        switch event {
        case .close: downstream?.close()
        case .error(let error):
            downstream?.error(error)
        case .connect(let upstream):
            self.upstream = upstream
            downstream?.connect(to: upstream)
        case .next(let input):
            flush()
            
            if downstreamDemand > 0 {
                downstream?.next(input)
            } else {
                self.backlog.append(contentsOf: input)
            }
        }
    }
    
    private func flush() {
        while backlog.count > 0, downstreamDemand > 0, let value = backlog.first {
            guard case .parsed(let data) = value else {
                return
            }
            
            backlog.removeFirst()
            
            downstream?.next(data)
        }
    }
    
    /// updates the parser's state
    private func update() {
        /// if demand is 0, we don't want to do anything
        guard downstreamDemand > 0 else {
            return
        }
        
        flush()
        
        switch state {
        case .awaitingUpstream:
            /// we are waiting for upstream, nothing to be done
            break
        case .ready:
            /// ask upstream for some data
            state = .awaitingUpstream
            upstream?.request()
        }
    }
    
    private func process(_ input: String) {
        let count = input.utf8.count
        
        _ = input.withCString(encodedAs: UTF8.self) { pointer in
            do {
                let mask = self.masking ? randomMask() : nil
                
                let frame = try Frame(op: .text, payload: ByteBuffer(start: pointer, count: count), mask: mask)
            } catch {
                self.onError(error)
            }
        }
    }
    
    public func output<S>(to inputStream: S) where S : InputStream, TextStream.Output == S.Input {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }
    
    public func connection(_ event: ConnectionEvent) {
        switch event {
        case .request(let count):
            /// downstream has requested output
            downstreamDemand += count
        case .cancel:
            /// FIXME: handle
            downstreamDemand = 0
        }
        
        update()
    }
}

extension WebSocket {
    /// Sends a string to the server
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/websocket/text-stream/)
    public func send(_ string: String) {
        self.connection.//send
    }
    
    /// Drains the TextStream into this closure.
    ///
    /// Any previously listening closures will be overridden
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/websocket/text-stream/)
    public func onText(_ closure: @escaping ((String) -> ())) -> AnyInputStream<String> {
        self.textStream.
        return AnyInputStream(self.textStream)
    }
}
