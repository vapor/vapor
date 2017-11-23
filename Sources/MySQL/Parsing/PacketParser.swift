import Async
import Bits
import libc

/// Parses buffers into packets
internal final class PacketParser : Async.Stream {
    var buffer: (buffer: MutableByteBuffer, containing: Int, sequenceId: UInt8)?
    
    public typealias Input = MutableByteBuffer
    public typealias Output = Packet

    /// Use a basic stream to easily implement our output stream.
    private var outputStream: BasicStream<Output> = .init()

    /// Creates a new PacketParser.
    init() {}

    /// See InputStream.onInput
    func onInput(_ input: MutableByteBuffer) {
        do {
            try parse(input)
        } catch {
            onError(error)
        }
    }

    /// See InputStream.onError
    func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    func onOutput<I>(_ input: I) where I : InputStream, Output == I.Input {
        outputStream.onOutput(input)
    }

    /// See CloseableStream.close
    func close() {
        outputStream.close()
    }

    /// See CloseableStream.onClose
    func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
    }
    
    func parse(_ input: MutableByteBuffer) throws {
        // If there's no input pointer, throw an error
        guard var pointer = input.baseAddress else {
            throw MySQLError(.invalidPacket)
        }
        
        // Capture the pointer's contentlength
        var length = input.count
        
        // If an existing packet it building
        if let (buffer, containing, sequenceId) = self.buffer {
            // Continue parsing from the start
            try parseInput(
                pointer: pointer,
                length: length,
                into: buffer,
                alreadyContaining: containing,
                sequenceId: sequenceId
            )
            // If a new packet is coming
        } else {
            // at least 4 packet bytes for new packets
            // TODO: internal 3-byte buffer like MongoKitten's for this odd scenario
            guard input.count > 3 else {
                if input.count == 0 {
                    return
                }
                
                throw MySQLError(.invalidPacket)
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
            try parseInput(
                pointer: pointer,
                length: length,
                into: buffer,
                alreadyContaining: 0,
                sequenceId: sequenceId
            )
        }
    }

    // Parses the buffer
    private func parseInput(
        pointer: UnsafeMutablePointer<Byte>,
        length: Int,
        into buffer: MutableByteBuffer,
        alreadyContaining containing: Int,
        sequenceId: UInt8
    ) throws {
        // If there's no input pointer, throw an error
        guard let destination = buffer.baseAddress?.advanced(by: containing) else {
            throw MySQLError(.invalidPacket)
        }

        // The rest of the packet
        let needing = buffer.count &- containing

        // If there's too much data
        if length > needing {
            // copy only the necessary
            memcpy(destination, pointer, needing)

            // Packet is complete, send it up
            let packet = Packet(sequenceId: sequenceId, payload: buffer)
            outputStream.onInput(packet)

            self.buffer = nil

            guard length &- needing > 0 else {
                return
            }

            let input = MutableByteBuffer(start: pointer.advanced(by: needing), count: length &- needing)
            onInput(input)
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
            outputStream.onInput(packet)

            self.buffer = nil
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
