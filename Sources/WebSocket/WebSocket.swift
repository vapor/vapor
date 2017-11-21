import Async
import Foundation
import Bits
import HTTP
import Crypto
import TCP

/// A websocket connection. Can be either the client or server side of the connection
///
/// [Learn More →](https://docs.vapor.codes/3.0/websocket/websocket/)
public final class WebSocket {
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
    public init<DuplexByteStream: Async.Stream>(client: DuplexByteStream, serverSide: Bool = true) where DuplexByteStream.Input == ByteBuffer, DuplexByteStream.Output == ByteBuffer, DuplexByteStream: ClosableStream {
        self.connection = Connection(client: client, serverSide: serverSide)
        
        self.textStream.frameStream = self.connection
        self.binaryStream.frameStream = self.connection
        
        self.connection.drain(self.processFrame).catch { error in
            // FIXME: @joannis
            fatalError("\(error)")
        }
    }
    
    /// Closes the connection to the other side by sending a `close` frame and closing the TCP connection
    public func close() {
        connection.close()
    }
}
