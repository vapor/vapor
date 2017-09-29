import Async
import Dispatch
import HTTP
import TCP

/// Manages frames to and from a TCP connection
internal final class Connection: Async.Stream {
    internal typealias Input = Frame
    internal typealias Output = Frame

    /// The incoming frames handelr
    var outputStream: OutputHandler?
    
    var errorStream: ErrorHandler?
    
    /// Serializes data into frames
    let serializer: FrameSerializer
    
    let serverSide: Bool

    /// The underlying TCP connection
    let client: TCP.Client
    
    /// Creates a new WebSocket Connection manager for a TCP.Client
    ///
    /// `serverSide` is used to determine if sent frames need to be masked
    init(client: TCP.Client, serverSide: Bool = true) {
        self.client = client
        self.serverSide = serverSide
        
        let parser = FrameParser()
        serializer = FrameSerializer(masking: !serverSide)
        
        // Streams incoming data into the parser which sends it to this frame's handler
        client.stream(to: parser).drain { frame in
            self.outputStream?(frame)
        }
        
        // Streams outgoing data to the serializer, which sends it over the socket
        serializer.drain { buffer in
            let buffer = UnsafeRawBufferPointer(buffer)
            client.inputStream(DispatchData(bytes: buffer))
        }
    }

    func inputStream(_ input: Frame) {
        serializer.inputStream(input)
    }
}
