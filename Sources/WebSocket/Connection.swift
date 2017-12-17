import Bits
import Async
import Dispatch
import HTTP
import TCP

/// Manages frames to and from a TCP connection
internal final class Connection: Async.Stream, ConnectionContext {
    /// See InputStream.Input
    typealias Input = Frame
    
    /// See OutputStream.Output
    typealias Output = Frame
    
    /// Serializes data into frames
    let serializer: FrameSerializer
    
    /// Parses frames from data
    let parser: FrameParser
    
    /// Defines the side of the socket
    ///
    /// Server side Sockets don't use masking
    let mode: WebSocketMode
    
    /// An array, for when a single TCP message has > 1 entity
    let backlog = [Frame]()

    /// Creates a new WebSocket Connection manager for a TCP.Client
    ///
    /// `serverSide` is used to determine if sent frames need to be masked
    init<Socket: DispatchSocket>(socket: Socket, mode: WebSocketMode, on eventloop: EventLoop) {
        self.mode = mode
        
        self.parser = socket.stream(on: eventloop).stream(to: FrameParser())
        self.serializer = FrameSerializer(masking: mode.masking)
        
        serializer.output(to: socket)
    }

    /// Sends the closing frame and closes the connection
//    func close() {
//        do {
//            let frame = try Frame(
//                op: .close,
//                payload: ByteBuffer(start: nil, count: 0),
//                mask: serverSide ? nil : randomMask(),
//                isFinal: true
//            )
//            self.onInput(frame)
//            self.socket.close()
//            outputStream.close()
//        } catch {
//            onError(error)
//        }
//    }
}
