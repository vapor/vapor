import Async
import Bits

/// A stream of incoming and outgoing strings between 2 parties over WebSockets
///
/// [Learn More →](https://docs.vapor.codes/3.0/websocket/text-stream/)
final class TextStream: Async.Stream {
    /// A framestream to stream text frames to
    internal weak var frameStream: Connection?
    
    typealias Input = String
    typealias Output = String
    
    /// Returns whether to add mask a mask to this message
    var masking: Bool {
        return frameStream?.serverSide == false
    }

    /// Use a basic stream to easily implement our output stream.
    private var outputStream: BasicStream<Output> = .init()
    
    /// Creates a new TextStream that has yet to be linked up with other streams
    init() { }
    
    /// Sends a string to the other party
    func onInput(_ input: String) {
        _ = input.withCString(encodedAs: UTF8.self) { pointer in
            do {
                let mask = self.masking ? randomMask() : nil
                
                let frame = try Frame(op: .text, payload: ByteBuffer(start: pointer, count: input.utf8.count), mask: mask)
                
                frameStream?.onInput(frame)
            } catch {
                self.onError(error)
            }
        }
    }

    /// See InputStream.onError
    func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    func onOutput<I>(_ input: I) where I : InputStream, Output == I.Input {
        outputStream.onOutput(input)
    }
}

extension WebSocket {
    /// Sends a string to the server
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/websocket/text-stream/)
    public func send(_ string: String) {
        self.textStream.onInput(string)
    }
    
    /// Drains the TextStream into this closure.
    ///
    /// Any previously listening closures will be overridden
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/websocket/text-stream/)
    public func onText(_ closure: @escaping ((String) -> ())) -> BasicStream<String> {
        return self.textStream.drain(onInput: closure)
    }
}
