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
    public init<ByteStream>(socket: ByteStream, serverSide: Bool = true)
        where ByteStream: Async.Stream,
            ByteStream.Input == ByteBuffer,
            ByteStream.Output == ByteBuffer,
            ByteStream: ClosableStream
    {
        self.connection = Connection(socket: socket, serverSide: serverSide)
        
        self.textStream.frameStream = self.connection
        self.binaryStream.frameStream = self.connection

        /// FIXME: use a stream splitter here? this api seems a bit odd
        self.connection.drain(onInput: self.processFrame).catch { error in
            self.textStream.onError(error)
            self.binaryStream.onError(error)
        }
    }
    
    /// Closes the connection to the other side by sending a `close` frame and closing the TCP connection
    public func close() {
        connection.close()
    }
}
