//import Async
//import Foundation
//import Bits
//
///// A stream of incoming and outgoing binary  between 2 parties over WebSockets
/////
///// [Learn More →](https://docs.vapor.codes/3.0/websocket/binary-stream/)
//final class BinaryStream : Async.Stream {
//    internal weak var frameStream: Connection?
//    
//    typealias Input = ByteBuffer
//    typealias Output = ByteBuffer
//
//    /// Returns whether to add mask a mask to this message
//    var masking: Bool {
//        return frameStream?.serverSide == false
//    }
//
//    /// Use a basic stream to easily implement our output stream.
//    var outputStream: BasicStream<Output> = .init()
//
//    /// Creates a new BinaryStream that has yet to be linked up with other streams
//    init() { }
//
//    /// Sends this binary data to the other party
//    func onInput(_ input: ByteBuffer) {
//        do {
//            let mask = self.masking ? randomMask() : nil
//
//            let frame = try Frame(op: .binary, payload: input, mask: mask)
//
//            if masking {
//                frame.mask()
//            }
//
//            frameStream?.onInput(frame)
//        } catch {
//            onError(error)
//        }
//    }
//
//    func onError(_ error: Error) {
//        outputStream.onError(error)
//    }
//
//    func onOutput<I>(_ input: I) where I : Async.InputStream, Output == I.Input {
//        outputStream.onOutput(input)
//    }
//
//    /// See CloseableStream.close
//    public func close() {
//        outputStream.close()
//    }
//
//    /// See CloseableStream.onClose
//    public func onClose(_ onClose: ClosableStream) {
//        outputStream.onClose(onClose)
//    }
//}
//
//extension WebSocket {
//    /// Sends binary data to the server
//    ///
//    /// [Learn More →](https://docs.vapor.codes/3.0/websocket/binary-stream/)
//    public func send(_ buffer: ByteBuffer) {
//        self.binaryStream.onInput(buffer)
//    }
//
//    /// Send binary data to the server
//    ///
//    /// [Learn More →](https://docs.vapor.codes/3.0/websocket/binary-stream/)
//    public func send(_ data: Data) {
//        data.withByteBuffer(self.send)
//    }
//
//    /// Drains the TextStream into this closure.
//    ///
//    /// Any previously listening closures will be overridden
//    ///
//    /// [Learn More →](https://docs.vapor.codes/3.0/websocket/binary-stream/)
//    public func onBinary(_ closure: @escaping ((ByteBuffer) -> ())) -> BasicStream<ByteBuffer> {
//        return self.binaryStream.drain(onInput: closure)
//    }
//}

