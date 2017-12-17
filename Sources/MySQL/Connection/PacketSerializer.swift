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
        // Starts the packet number at the starting number
        // The handshake starts at 1, instead of 0
        
        flush(input.buffer)
    }
}
