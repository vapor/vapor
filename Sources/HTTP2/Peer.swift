import Core
import TCP

public final class HTTP2Peer: Core.Stream {
    public typealias Input = Frame
    public typealias Output = Frame
    
    let client: TCP.Client
    let frameParser = FrameParser()
    let frameSerializer = FrameSerializer()
    
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?
    
    public var maxFrameSize: UInt32 = 16_384
    
    public init(for client: TCP.Client) {
        self.client = client
        
        client.stream(to: frameParser).drain { frame in
            print(frame)
        }
        
        frameSerializer.drain(into: client)
    }
    
    public func inputStream(_ input: Frame) {
        frameSerializer.inputStream(input)
    }
}
