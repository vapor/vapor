import Async
import Bits

/// Various states the parser stream can be in
enum ProtocolSerializerState {
    /// normal state
    case ready
    
    /// waiting for data from upstream
    case awaitingUpstream
}

final class MySQLPacketSerializer: Async.Stream {
    /// See InputStream.Input
    typealias Input = Packet
    
    /// See OutputStream.RedisData
    typealias Output = ByteBuffer
    
    var backlog: [Packet]
    
    var sendingPacket: Packet?
    
    var consumedBacklog: Int
    
    var downstreamDemand: UInt
    
    var serializing: Packet?
    
    var upstream: ConnectionContext?
    
    var downstream: AnyInputStream<MySQLPacketSerializer.Output>?
    
    var state: ProtocolParserState
    
    fileprivate var _sequenceId: UInt8
    
    var sequenceId: UInt8 {
        get {
            defer { _sequenceId = _sequenceId &+ 1 }
            return _sequenceId
        }
        set {
            _sequenceId = newValue
        }
    }
    
    init() {
        state = .ready
        self.downstreamDemand = 0
        self.consumedBacklog = 0
        self._sequenceId = 0
        self.backlog = []
    }
    
    /// See InputStream.input
    func input(_ event: InputEvent<Input>) {
        switch event {
        case .close: downstream?.close()
        case .error(let error): downstream?.error(error)
        case .connect(let upstream):
            self.upstream = upstream
            downstream?.connect(to: upstream)
        case .next(let input):
            self.flush(input)
        }
    }
    
    func connect(to context: ConnectionContext) {
        
    }
    
    /// See OutputStream.output
    func output<S>(to inputStream: S) where S: Async.InputStream, Output == S.Input {
        downstream = AnyInputStream(inputStream)
    }
    
    func nextCommandPhase() {
        self.sequenceId = 0
    }
    
    func serialize(_ input: Packet) throws {
        guard input.containsPacketSize else {
            fatalError("Server message sent to server")
        }
        
        // FIXME:
        flush(input)
    }
    
    func flush(_ packet: Packet) {
        guard downstreamDemand > 0 else {
            return
        }
        
        packet.sequenceId = self.sequenceId
        
        self.serializing = packet
        downstream?.next(packet.buffer)
    }

    func queue(_ packet: Packet, nextPhase: Bool = true) {
        if nextPhase {
            self.nextCommandPhase()
        }
        
        self.flush(packet)
    }
}
