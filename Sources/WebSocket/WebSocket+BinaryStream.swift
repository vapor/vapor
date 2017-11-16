import Async
import Bits

/// A stream of incoming and outgoing binary  between 2 parties over WebSockets
///
/// [For more information, see the documentation](https://docs.vapor.codes/3.0/websocket/binary-stream/)
final class BinaryStream : Async.Stream {
    /// A stream of incoming binary data
    var outputStream: OutputHandler?
    
    internal weak var frameStream: Connection?
    
    /// A stream of errors
    ///
    /// Will only be called if there's a problem creating a frame for output
    var errorStream: ErrorHandler?
    
    typealias Input = ByteBuffer
    typealias Output = ByteBuffer
    
    /// Returns whether to add mask a mask to this message
    var masking: Bool {
        return frameStream?.serverSide == false
    }
    
    /// Creates a new BinaryStream that has yet to be linked up with other streams
    init() { }
    
    /// Sends this binary data to the other party
    func inputStream(_ input: ByteBuffer) {
        do {
            let mask = self.masking ? randomMask() : nil
            
            let frame = try Frame(op: .binary, payload: input, mask: mask)
            
            if masking {
                frame.mask()
            }
            
            frameStream?.inputStream(frame)
        } catch {
            self.errorStream?(error)
        }
    }
}


extension WebSocket {
    /// Sends a string to the server
    ///
    /// [For more information, see the documentation](https://docs.vapor.codes/3.0/websocket/binary-stream/)
    public func send(_ buffer: ByteBuffer) {
        self.binaryStream.inputStream(buffer)
    }
    
    /// Drains the TextStream into this closure.
    ///
    /// Any previously listening closures will be overridden
    ///
    /// [For more information, see the documentation](https://docs.vapor.codes/3.0/websocket/binary-stream/)
    public func onBinary(_ closure: @escaping ((ByteBuffer) -> ())) {
        self.binaryStream.drain(closure).catch { error in
            // FIXME: @joannis
            fatalError("\(error)")
        }
    }
}
