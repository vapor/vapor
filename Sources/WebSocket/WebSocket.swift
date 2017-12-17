import Async
import Foundation
import Bits
import HTTP
import Crypto
import TCP

/// A websocket connection. Can be either the client or server side of the connection
///
/// [Learn More →](https://docs.vapor.codes/3.0/websocket/websocket/)
public class WebSocket {
    /// A stream of strings received from the remote
    let stringOutputStream: MapStream<Frame, String?>
    
    /// A stream of binary data received from the remote
    let binaryOutputStream: MapStream<Frame, ByteBuffer>
    
    /// Serializes data into frames
    let serializer: FrameSerializer
    
    /// Parses frames from data
    let parser: FrameParser
    
    /// Defines the side of the socket
    ///
    /// Server side Sockets don't use masking
    let mode: WebSocketMode
    
    /// The underlying communication layer
    let socket: AnyStream<ByteBuffer, ByteBuffer>
    
    /// Create a new WebSocket from a TCP client for either the Client or Server Side
    ///
    /// Server side connections do not mask sent data
    ///
    /// - parameter client: The TCP.Client that the WebSocket connection runs on
    /// - parameter serverSide: If `true`, run the WebSocket as a server side connection.
    init(socket: AnyStream<ByteBuffer, ByteBuffer>, server: Bool = true)
    {
        self.parser = socket.stream(to: FrameParser())
        self.serializer = FrameSerializer(masking: !server)
        self.socket = socket
        
        serializer.output(to: socket)
        
        self.stringOutputStream = MapStream<Frame, String?> { frame in
            let data = Data(buffer: frame.buffer)
            return String(data: data, encoding: .utf8)
        }
        
        self.binaryOutputStream = MapStream<Frame, ByteBuffer> { frame in
            return ByteBuffer(start: frame.buffer.baseAddress, count: frame.buffer.count)
        }
        
//        parser.drain { frame in
//            switch frame.opCode {
//            case .close:
//                self.connection.close()
//            case .ping:
//                frame.opCode = .pong
//
//                // Invert the remote's mask
//                // If the remote is a server, we're the client and vice versa
//                frame.toggleMask()
//                self.connection.in
//            }
//        }.stream(to: self.connection)
    }
    
    /// Closes the connection to the other side by sending a `close` frame and closing the TCP connection
    public func close() {
        socket.close()
    }
}

/// Various states a WebSocket stream can be in
enum WebSocketStreamState {
    /// normal state
    case ready
    
    /// waiting for data from upstream
    case awaitingUpstream
}
