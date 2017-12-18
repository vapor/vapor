import Async
import Bits

final class MySQLPacketSerializer: ProtocolSerializerStream {
    /// See InputStream.Input
    typealias Input = Packet
    
    /// See OutputStream.RedisData
    typealias Output = ByteBuffer
    
    var backlog: [Packet]
    
    var sendingPacket: Packet?
    
    var consumedBacklog: Int
    
    var serializing: Packet?
    
    var downstreamDemand: UInt
    
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
        downstreamDemand = 0
        state = .ready
        self.consumedBacklog = 0
        self._sequenceId = 0
        self.backlog = []
    }
    
    func nextCommandPhase() {
        self.sequenceId = 0
    }
    
    func serialize(_ input: Packet) throws {
        guard input.containsPacketSize else {
            fatalError("Server message sent to server")
        }
        
        // FIXME:
        input.sequenceId = self.sequenceId
        sendingPacket = input
        
        flush(input.buffer)
    }

    func queue(_ packet: Packet, nextPhase: Bool = true) {
        if nextPhase {
            self.nextCommandPhase()
        }
        
        // FIXME:
        packet.sequenceId = self.sequenceId
        
        if downstreamDemand > 0 {
            sendingPacket = packet
            
            self.flush(packet.buffer)
        } else {
            self.backlog.append(packet)
        }
    }
}
