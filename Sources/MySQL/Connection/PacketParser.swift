import Async
import Bits
import COperatingSystem

/// Parses buffers into packets
internal final class MySQLPacketParser: Async.Stream, ConnectionContext {
    /// See InputStream.Input
    typealias Input = ByteBuffer
    
    /// See OutputStream.RedisData
    typealias Output = Packet
    
    /// The in-progress parsing value
    var parsing: (buffer: MutableByteBuffer, containing: Int)?
    
    /// Internal buffer that keeps tack of an uncompleted packet header (size: UInt24) + (sequenceID: UInt8)
    private var headerBytes = [UInt8]()
    
    /// An array, for when a single TCP message has > 1 entity
    var backlog: [Output]
    
    /// Keeps track of the backlog that is already drained but not removed
    var consumedBacklog: Int
    
    /// The upstream providing byte buffers
    var upstream: ConnectionContext?
    
    var upstreamBuffer: ByteBuffer?
    var upstreamBufferOffset: Int = 0
    
    /// Must not be called before input
    /// The remaining length after `pointer`
    var length: Int {
        return upstreamBuffer!.count &- upstreamBufferOffset
    }
    
    /// Must not be called before input
    ///
    /// The current position of reading
    var pointer: BytesPointer {
        return upstreamBuffer!.baseAddress!.advanced(by: upstreamBufferOffset)
    }
    
    /// Use a basic output stream to implement server output stream.
    var downstream: AnyInputStream<Output>?
    
    /// Remaining downstream demand
    var downstreamDemand: UInt
    
    /// Current state
    var state: ProtocolParserState

    /// Create a new packet parser
    init() {
        downstreamDemand = 0
        self.backlog = []
        self.consumedBacklog = 0
        state = .ready
    }
    
    func transform(_ input: ByteBuffer) throws {
        self.upstreamBuffer = input
        self.upstreamBufferOffset = 0
        
        while downstreamDemand > 0, length > 0 {
            parseNext()
        }
    }
    
    private func parseNext() {
        // If an existing packet it building
        if let (buffer, containing) = self.parsing {
            let dataSize = min(buffer.count &- containing, length)
            
            memcpy(buffer.baseAddress!, pointer, dataSize)
            
            upstreamBufferOffset += dataSize
            
            if dataSize &+ containing == buffer.count {
                // Packet is complete, send it up
                let packet = Packet(payload: buffer)
                flush(packet)
            } else {
                // Wait for more data
                self.parsing = (buffer, dataSize &+ containing)
                upstream?.request()
            }
        } else {
            // Continue parsing from the start
            if headerBytes.count == 0 {
                guard length >= 3 else {
                    dumpHeader()
                    return
                }
                
                let byte0: UInt32 = (numericCast(pointer[0]) as UInt32).littleEndian
                let byte1: UInt32 = (numericCast(pointer[1]) as UInt32).littleEndian << 8
                let byte2: UInt32 = (numericCast(pointer[2]) as UInt32).littleEndian << 16
                
                let payloadSize = numericCast(byte0 | byte1 | byte2) as Int
                
                // sequenceID + payload
                let fullPacketSize = 1 &+ payloadSize
                
                upstreamBufferOffset = upstreamBufferOffset &+ 3
                
                if length < fullPacketSize {
                    dumpPayload(size: fullPacketSize)
                } else {
                    flushPayload(size: fullPacketSize)
                }
            } else {
                guard let header = parseHeader() else {
                    return
                }
                
                let fullPacketSize = 1 &+ header
                
                if length < fullPacketSize {
                    dumpPayload(size: fullPacketSize)
                } else {
                    flushPayload(size: fullPacketSize)
                }
            }
        }
    }
    
    private func flushPayload(size: Int) {
        // we don't need to copy this
        let buffer = ByteBuffer(start: pointer, count: size)
        
        upstreamBufferOffset = upstreamBufferOffset &+ size
        
        // Packet is complete, send it up
        let packet = Packet(payload: buffer)
        flush(packet)
    }
    
    private func dumpHeader() {
        guard headerBytes.count &+ length < 3 else {
            fatalError("Dumping MySQL packet header which is large enough to parse")
        }
        
        // at least 4 packet bytes for new packets
        if length == 0 {
            return
        }
        
        if length == 1 {
            headerBytes += [
                pointer[0]
            ]
        } else if length == 2 {
            headerBytes += [
                pointer[0], pointer[1]
            ]
        } else {
            headerBytes += [
                pointer[0], pointer[1], pointer[1]
            ]
        }
        
        upstream?.request()
        return
    }
    
    private func dumpPayload(size: Int) {
        // dump payload inside packet
        // Build a buffer size, we need to copy this since it's not complete
        let bufferPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        let buffer = MutableByteBuffer(start: bufferPointer, count: size)
        
        let containing = min(length, size)
        memcpy(bufferPointer, pointer, containing)
        
        self.parsing = (buffer, containing)
        upstream?.request()
    }
    
    /// Do not call this function is the headerBytes size == 0
    private func parseHeader() -> Int? {
        guard headerBytes.count > 0 else {
            fatalError("Incorrect usage of MySQL packet header parsing")
        }
        
        guard length &+ headerBytes.count >= 3 else {
            dumpHeader()
            return nil
        }
        
        let byte0: UInt32
        let byte1: UInt32
        let byte2: UInt32
        
        // take the first 3 bytes
        // Take the cached previous packet edge-case bytes into consideration
        switch headerBytes.count {
        case 1:
            byte0 = (numericCast(headerBytes[0]) as UInt32).littleEndian
            
            byte1 = (numericCast(pointer[0]) as UInt32).littleEndian << 8
            byte2 = (numericCast(pointer[1]) as UInt32).littleEndian << 16
            self.upstreamBufferOffset += 2
            
            headerBytes = []
        case 2:
            byte0 = (numericCast(headerBytes[0]) as UInt32).littleEndian
            byte1 = (numericCast(headerBytes[1]) as UInt32).littleEndian << 8
            
            byte2 = (numericCast(pointer[0]) as UInt32).littleEndian << 16
            self.upstreamBufferOffset += 1
            
            headerBytes = []
        default:
            fatalError("Invalid scenario reached")
        }
        
        return numericCast(byte0 | byte1 | byte2) as Int
    }
}

extension Packet {
    /// Parses the field definition from a packet
    func parseFieldDefinition() throws -> Field {
        var parser = Parser(packet: self)
        
        try parser.skipLenEnc() // let catalog = try parser.parseLenEncString()
        try parser.skipLenEnc() // let database = try parser.parseLenEncString()
        try parser.skipLenEnc() // let table = try parser.parseLenEncString()
        try parser.skipLenEnc() // let originalTable = try parser.parseLenEncString()
        let name = try parser.parseLenEncString()
        try parser.skipLenEnc() // let originalName = try parser.parseLenEncString()
        
        parser.position += 1
        
        let charSet = try parser.byte()
        let collation = try parser.byte()
        
        let length = try parser.parseUInt32()
        
        guard let fieldType = Field.FieldType(rawValue: try parser.byte()) else {
            throw MySQLError(.invalidPacket)
        }
        
        let flags = Field.Flags(rawValue: try parser.parseUInt16())
        
        let decimals = try parser.byte()
        
        return Field(
            catalog: nil,
            database: nil,
            table: nil,
            originalTable: nil,
            name: name,
            originalName: nil,
            charSet: charSet,
            collation: collation,
            length: length,
            fieldType: fieldType,
            flags: flags,
            decimals: decimals
        )
    }
}
