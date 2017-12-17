import COperatingSystem
import Async
import Bits

/// Serializes frames to binary
final class FrameSerializer: ProtocolSerializerStream {
    /// See InputStream.Input
    typealias Input = Frame
    
    /// See OutputStream.Output
    typealias Output = ByteBuffer
    
    var serializing: Input?
    
    var serializationState: Output.State?
    
    func serialize(_ input: Input, state: Output.State) throws -> Output.State {
        let taken = Swift.min(65_507, self.count - state)
        let buffer = UnsafeBufferPointer<Element>(start: self.baseAddress?.advanced(by: state), count: taken)
        
        
        
        return state + taken
    }
    
    func input(_ event: InputEvent<Frame>) {
        <#code#>
    }
    
    func output<S>(to inputStream: S) where S : InputStream, Output == S.Input {
        <#code#>
    }
    
    func connection(_ event: ConnectionEvent) {
        <#code#>
    }
    
    /// An array with the additional unserialized frames
    var backlog: [Frame]
    
    var currentBuffer: Frame
    
    var currentOffset: Int
    
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
    }

    func onInput(_ input: Frame) {
        // masks the data if needed
        if mask {
            input.mask()
        } else {
            input.unmask()
        }

        outputStream.onInput(ByteBuffer(start: input.buffer.baseAddress, count: input.buffer.count))
    }

    func onError(_ error: Error) {
        outputStream.onError(error)
    }

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

