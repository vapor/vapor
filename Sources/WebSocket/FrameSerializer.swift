import COperatingSystem
import Async
import Bits

/// Serializes frames to binary
final class FrameSerializer: Async.Stream, ConnectionContext {
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
    
    var sendingFrame: Frame?
    
    var parsing: ByteBuffer? {
        didSet {
            parsedBytes = 0
        }
    }
    
    var parsedBytes: Int = 0
    
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
    
    func input(_ event: InputEvent<Frame>) {
        switch event {
        case .close:
            downstream?.close()
        case .connect(let upstream):
            self.upstream = upstream
        case .error(let error):
            downstream?.error(error)
        case .next(let frame):
            self.queue(frame)
        }
    }
    
    func output<S>(to inputStream: S) where S : Async.InputStream, Output == S.Input {
        self.downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }

    func queue(_ frame: Frame) {
        if downstreamDemand > 0 {
            self.flush(frame)
        } else {
            self.backlog.append(frame)
        }
    }
    
    func connection(_ event: ConnectionEvent) {
        switch event {
        case .cancel:
            self.downstreamDemand = 0
        case .request(let demand):
            self.downstreamDemand += demand
        }
        
        defer {
            self.backlog.removeFirst(consumedBacklog)
        }
        
        while downstreamDemand > 0, parsing != nil {
            guard backlog.count > consumedBacklog else {
                upstream?.request()
                return
            }
            
            flush(self.backlog[consumedBacklog])
            consumedBacklog += 1
        }
    }
    
    func flush(_ frame: Frame) {
        downstreamDemand -= 1
        self.serializing = frame
        downstream?.next(ByteBuffer(start: frame.buffer.baseAddress, count: frame.buffer.count))
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

