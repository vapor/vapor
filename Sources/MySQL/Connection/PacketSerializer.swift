import Async
import Bits

/// Various states the parser stream can be in
enum ProtocolSerializerState {
    /// normal state
    case ready
    
    /// waiting for data from upstream
    case awaitingUpstream
}

final class MySQLPacketSerializer: Async.Stream, ConnectionContext {
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
    
    func connection(_ event: ConnectionEvent) {
        switch event {
        case .cancel:
            self.downstreamDemand = 0
        case .request(let req):
            self.downstreamDemand += req
        }
        
        flush(nil)
    }
    
    /// See OutputStream.output
    func output<S>(to inputStream: S) where S: Async.InputStream, Output == S.Input {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
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
    
    func flush(_ packet: Packet?) {
        guard downstreamDemand > 0 else {
            if let packet = packet {
                self.backlog.append(packet)
            }
            return
        }
        
        if backlog.count > consumedBacklog {
            defer {
                backlog.removeFirst(consumedBacklog)
            }
            
            let frame = backlog[consumedBacklog]
            self.serializing = frame
            self.downstream?.next(frame.buffer)
            
            if let packet = packet {
                self.backlog.append(packet)
            }
        } else if let packet = packet {
            packet.sequenceId = self.sequenceId
            
            self.serializing = packet
            downstream?.next(packet.buffer)
        }
    }

    func queue(_ packet: Packet, nextPhase: Bool = true) {
        if nextPhase {
            self.nextCommandPhase()
        }
        
        self.flush(packet)
    }
}
