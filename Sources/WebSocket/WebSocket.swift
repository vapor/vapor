import Foundation
import Bits
import HTTP
import Crypto
import TCP

/// A websocket connection. Can be either the client or server side of the connection
public class WebSocket {
    /// A stream of incoming and outgoing strings between both parties
    let textStream = TextStream()
    
    /// A stream of incoming and outgoing binary blobs between both parties
    let binaryStream = BinaryStream()
    
    /// The internal connection that communicates the frames
    let connection: Connection

    /// Create a new WebSocket from a TCP client for either the Client or Server Side
    ///
    /// Server side connections do not mask sent data
    ///
    /// - parameter client: The TCP.Client that the WebSocket connection runs on
    /// - parameter serverSide: If `true`, run the WebSocket as a server side connection.
    public init(client: TCP.Client, serverSide: Bool = true) {
        self.connection = Connection(client: client, serverSide: serverSide)
        
        self.textStream.frameStream = self.connection
        self.binaryStream.frameStream = self.connection
        
        self.connection.drain(self.processFrame)
    }
    
    /// Closes the connection to the other side by sending a `close` frame and closing the TCP connection
    public func close() {
        do {
            let frame = try Frame(op: .close, payload: ByteBuffer(start: nil, count: 0), mask: connection.serverSide ? nil : randomMask(), isFinal: true)
            
            self.connection.inputStream(frame)
            self.connection.client.close()
        } catch {}
    }
}
