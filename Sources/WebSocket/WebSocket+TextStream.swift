import Async
import Bits

/// A stream of incoming and outgoing strings between 2 parties over WebSockets
final class TextStream : Async.Stream {
    /// A stream of strings received from the other party
    var outputStream: OutputHandler?
    
    /// A framestream to stream text frames to
    internal weak var frameStream: Connection?
    
    /// A stream of errors
    ///
    /// Will only be called if there's a problem creating a frame for output
    var errorStream: ErrorHandler?
    
    typealias Input = String
    typealias Output = String
    
    /// Returns whether to add mask a mask to this message
    var masking: Bool {
        return frameStream?.serverSide == false
    }
    
    /// Creates a new TextStream that has yet to be linked up with other streams
    init() { }
    
    /// Sends a string to the other party
    func inputStream(_ input: String) {
        _ = input.withCString(encodedAs: UTF8.self) { pointer in
            do {
                let mask = self.masking ? randomMask() : nil
                
                let frame = try Frame(op: .text, payload: ByteBuffer(start: pointer, count: input.utf8.count), mask: mask)
                
                frameStream?.inputStream(frame)
            } catch {
                self.errorStream?(error)
            }
        }
    }
}

extension WebSocket {
    /// Sends a string to the server
    public func send(_ string: String) {
        self.textStream.inputStream(string)
    }
    
    /// Drains the TextStream into this closure.
    ///
    /// Any previously listening closures will be overridden
    public func onText(_ closure: @escaping ((String) -> ())) {
        self.textStream.drain(closure)
    }
}
