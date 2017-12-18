import Async
import Bits

final class MySQLPacketSerializer: ProtocolSerializerStream {
    /// See InputStream.Input
    typealias Input = Packet
    
    /// See OutputStream.RedisData
    typealias Output = ByteBuffer
    
    var backlog: [Packet]
    
    var consumedBacklog: Int
    
    var serializing: Packet?
    
    var downstreamDemand: UInt
    
    var upstream: ConnectionContext?
    
    var downstream: AnyInputStream<MySQLPacketSerializer.Output>?
    
    var state: ProtocolParserState
    
    init() {
        downstreamDemand = 0
        state = .ready
        self.consumedBacklog = 0
        self.backlog = []
    }
    
    func serialize(_ input: Packet) throws {
        guard input.containsPacketSize else {
            fatalError("Server message sent to server")
        }
        
        flush(input.buffer)
    }

    func queue(_ packet: Packet) {
        if downstreamDemand > 0 {
            self.flush(packet.buffer)
        } else {
            self.backlog.append(packet)
        }
    }
}
