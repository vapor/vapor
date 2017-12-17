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
    
    var backlog: [Frame]
    
    /// Serializes data into frames
//    let serializer: FrameSerializer
    
    /// Parses frames from data
    let parser: FrameParser
    
    let server: Bool
    
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
        self.backlog = []
        self.parser = socket.stream(to: FrameParser())
        self.serializer = FrameSerializer(masking: !server)
        self.socket = socket
        self.server = server
        
        self.stringOutputStream = MapStream<Frame, String?> { frame in
            let data = Data(buffer: frame.buffer)
            return String(data: data, encoding: .utf8)
        }
        
        self.binaryOutputStream = MapStream<Frame, ByteBuffer> { frame in
            return ByteBuffer(start: frame.buffer.baseAddress, count: frame.buffer.count)
        }
        
        func bindFrameStreams() {
            
        }
        
        if server {
            bindFrameStreams()
        } else {
            // Generates the UUID that will make up the WebSocket-Key
            let id = OSRandom().data(count: 16).base64EncodedString()
            
            // Creates an HTTP client for the handshake
            let HTTPSerializer = HTTPRequestSerializer().stream()
            
            let HTTPParser = HTTPResponseParser(maxSize: 50_000).stream()
            
            HTTPSerializer.output(to: socket)
            
            let drain = DrainStream<HTTPResponse>(onInput: { response in
                try WebSocket.upgrade(response: response, id: id)
                
                bindFrameStreams()
            })
            
            socket.stream(to: HTTPParser).output(to: drain)
        }
    }
    
    /// Closes the connection to the other side by sending a `close` frame and closing the TCP connection
    public func close() {
        socket.close()
    }
}//extension WebSocket {
//    /// A helper that processes a frame and directs it to the proper handler.
//    ///
//    /// Automatically replies to `ping` and automatically handles `close`
//    func processFrame(_ frame: Frame) {
//        // Unmasks the data so it's readable
//        frame.unmask()
//
//        func processString() {
//            // If this is an UTF-8 invalid string
//            guard let string = frame.payload.string() else {
//                self.connection.close()
//                return
//            }
//
//            // Stream to the textStream's listener
//            self.textStream.outputStream.onInput(string)
//        }
//
//        func processBinary() {
//            // Stream to the binaryStream's listener
//            self.binaryStream.outputStream.onInput(frame.payload)
//        }
//
//        switch frame.opCode {
//        case .text:
//            processString()
//        case .binary:
//            processBinary()
//        case .ping:
//            do {
//                // reply the input
//                let pongFrame = try Frame(op: .pong , payload: frame.payload, mask: frame.maskBytes, isMasked: self.connection.serverSide)
//                self.connection.onInput(pongFrame)
//            } catch {
//                self.connection.onError(error)
//            }
//        case .continuation:
//            processBinary()
//        case .close:
//            self.connection.close()
//        case .pong:
//            return
//        }
//    }
//}
