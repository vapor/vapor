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
    /// The internal connection that communicates the frames
    let connection: Connection
    
    /// A stream of strings received from the remote
    let stringOutputStream: MapStream<Frame, String?>
    
    /// A stream of binary data received from the remote
    let binaryOutputStream: MapStream<Frame, ByteBuffer>

    /// Create a new WebSocket from a TCP client for either the Client or Server Side
    ///
    /// Server side connections do not mask sent data
    ///
    /// - parameter client: The TCP.Client that the WebSocket connection runs on
    /// - parameter serverSide: If `true`, run the WebSocket as a server side connection.
    public init(socket: DispatchSocket, server: Bool = true)
    {
        self.connection = Connection(socket: socket, mode: server ? .server: .client)
        
        self.stringOutputStream = MapStream<Frame, String?> { frame in
            let data = Data(buffer: frame.buffer)
            return String(data: data, encoding: .utf8)
        }
        
        self.binaryOutputStream = MapStream<Frame, ByteBuffer> { frame in
            return ByteBuffer(start: frame.buffer.baseAddress, count: frame.buffer.count)
        }
        
//        self.connection.split { frame in
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
        connection.close()
    }
}

/// Various states a WebSocket stream can be in
enum WebSocketStreamState {
    /// normal state
    case ready
    
    /// waiting for data from upstream
    case awaitingUpstream
}
