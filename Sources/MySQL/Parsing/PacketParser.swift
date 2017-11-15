import Async
import Bits
import libc

/// Parses buffers into packets
internal final class PacketParser : Async.Stream {
    var buffer: (buffer: MutableByteBuffer, containing: Int, sequenceId: UInt8)?
    
    var outputStream: ((Packet) -> ())?
    var errorStream: BaseStream.ErrorHandler?
    
    public typealias Input = MutableByteBuffer
    public typealias Output = Packet
    
    init() {}
    
    func inputStream(_ input: MutableByteBuffer) {
        // If there's no input pointer, throw an error
        guard var pointer = input.baseAddress else {
            errorStream?(MySQLError(.invalidPacket))
            return
        }
        
        // Capture the pointer's contentlength
        var length = input.count
        
        // Parses the buffer
        func parseInput(into buffer: MutableByteBuffer, alreadyContaining containing: Int, sequenceId: UInt8) {
            // If there's no input pointer, throw an error
            guard let destination = buffer.baseAddress?.advanced(by: containing) else {
                errorStream?(MySQLError(.invalidPacket))
                return
            }
            
            // The rest of the packet
            let needing = buffer.count &- containing
            
            // If there's too much data
            if length > needing {
                // copy only the necessary
                memcpy(destination, pointer, needing)
                
                // Packet is complete, send it up
                let packet = Packet(sequenceId: sequenceId, payload: buffer)
                outputStream?(packet)
                
                self.buffer = nil
                
                guard length &- needing > 0 else {
                    return
                }
                
                self.inputStream(MutableByteBuffer(start: pointer.advanced(by: needing), count: length &- needing))
                
                // If we have exactly enough or too little
            } else {
                memcpy(destination, pointer, length)
                
                // If the packet is not complete yet
                guard containing &+ length == buffer.count else {
                    // update the partial packet
                    self.buffer = (buffer, containing &+ length, sequenceId)
                    return
                }
                
                // Packet is complete, send it up
                let packet = Packet(sequenceId: sequenceId, payload: buffer)
                outputStream?(packet)
                
                self.buffer = nil
            }
        }
        
        // If an existing packet it building
        if let (buffer, containing, sequenceId) = self.buffer {
            // Continue parsing from the start
            parseInput(into: buffer, alreadyContaining: containing, sequenceId: sequenceId)
            // If a new packet is coming
        } else {
            // at least 4 packet bytes for new packets
            // TODO: internal 3-byte buffer like MongoKitten's for this odd scenario
            guard input.count > 3 else {
                if input.count == 0 {
                    return
                }
                
                errorStream?(MySQLError(.invalidPacket))
                return
            }
            
            // take the first 3 bytes
            let byte0 = UInt32(input[0]).littleEndian
            let byte1 = UInt32(input[1]).littleEndian << 8
            let byte2 = UInt32(input[2]).littleEndian << 16
            
            // Parse buffer size
            let bufferSize = Int(byte0 | byte1 | byte2)
            let sequenceId = input[3]
            
            // Build a buffer size
            let bufferPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            let buffer = MutableByteBuffer(start: bufferPointer, count: bufferSize)
            
            // Advance the pointer by the header size
            pointer = pointer.advanced(by: 4)
            
            // Decrease the pointer size by the header size
            length = length &- 4
            
            // Parse the packet contents
            parseInput(into: buffer, alreadyContaining: 0, sequenceId: sequenceId)
        }
    }
}

extension Packet {
    /// Parses the field definition from a packet
    func parseFieldDefinition() throws -> Field {
        let parser = Parser(packet: self)
        
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
