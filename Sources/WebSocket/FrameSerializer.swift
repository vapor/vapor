import COperatingSystem
import Async
import Bits

/// Serializes frames to binary
final class FrameSerializer: ProtocolSerializerStream {
    /// See InputStream.Input
    typealias Input = Frame
    
    /// See OutputStream.Output
    typealias Output = ByteBuffer
    
    var serializing: Input? {
        didSet {
            serializationProgress = 0
            
            // masks the data if needed, works _only_ because this is a class
            if mask {
                serializing?.mask()
            } else {
                serializing?.unmask()
            }
        }
    }
    
    var serializationProgress: Int
    
    /// An array with the additional unserialized frames
    var backlog: [Frame]
    
    var consumedBacklog: Int
    
    var downstreamDemand: UInt
    
    var upstream: ConnectionContext?
    
    var downstream: AnyInputStream<ByteBuffer>?
    
    var state: ProtocolParserState
    
    /// If true, masks the messages before sending
    let mask: Bool

    /// Creates a FrameSerializer
    ///
    /// If masking, masks the messages before sending
    ///
    /// Only clients send masked messages
    init(masking: Bool) {
        self.mask = masking
        self.serializationProgress = 0
        self.downstream = nil
        self.backlog = []
        self.consumedBacklog = 0
        self.state = .ready
        self.downstreamDemand = 0
    }

    func queue(_ packet: Frame) {
        fatalError("implement me")
    }

    func serialize(_ input: Input) throws {
        let pointer = input.buffer.baseAddress?.advanced(by: serializationProgress)
        
        let unserialized = input.buffer.count - serializationProgress
        let size = Swift.min(unserialized, 65_507)
        
        let buffer = ByteBuffer(start: pointer, count: size)
        
        flush(buffer)
        
        if unserialized - size > 0 {
            self.serializing = input
            self.serializationProgress += size
        } else {
            self.serializing = nil
        }
    }
}

/// Generates a random mask for client sockets
func randomMask() -> [UInt8] {
    var buffer: [UInt8] = [0,0,0,0]
    
    var number: UInt32
    
    #if os(Linux)
        number = numericCast(COperatingSystem.random() % Int(UInt32.max))
    #else
        number = arc4random_uniform(UInt32.max)
    #endif
    
    memcpy(&buffer, &number, 4)
    
    return buffer
}

