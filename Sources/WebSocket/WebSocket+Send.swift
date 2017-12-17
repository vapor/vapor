//import COperatingSystem
//import Async
//import Bits
//
///// Serializes frames to binary
//final class FrameSerializer : Async.Stream {
//    /// See InputStream.Input
//    typealias Input = Frame
//    
//    /// See OutputStream.Output
//    typealias Output = ByteBuffer
//
//    /// If true, masks the messages before sending
//    let mask: Bool
//
//    /// Use a basic stream to easily implement our output stream.
//    private var outputStream: BasicStream<Output> = .init()
//    
//    /// Creates a FrameSerializer
//    ///
//    /// If masking, masks the messages before sending
//    ///
//    /// Only clients send masked messages
//    init(masking: Bool) {
//        self.mask = masking
//    }
//
//    func onInput(_ input: Frame) {
//        // masks the data if needed
//        if mask {
//            input.mask()
//        } else {
//            input.unmask()
//        }
//
//        outputStream.onInput(ByteBuffer(start: input.buffer.baseAddress, count: input.buffer.count))
//    }
//
//    func onError(_ error: Error) {
//        outputStream.onError(error)
//    }
//
//    func onOutput<I>(_ input: I) where I : InputStream, Output == I.Input {
//        outputStream.onOutput(input)
//    }
//
//    /// See CloseableStream.close
//    func close() {
//        outputStream.close()
//    }
//
//    /// See CloseableStream.onClose
//    func onClose(_ onClose: ClosableStream) {
//        outputStream.onClose(onClose)
//    }
//}
//
///// Generates a random mask for client sockets
//func randomMask() -> [UInt8] {
//    var buffer: [UInt8] = [0,0,0,0]
//    
//    var number: UInt32
//    
//    #if os(Linux)
//        number = numericCast(COperatingSystem.random() % Int(UInt32.max))
//    #else
//        number = arc4random_uniform(UInt32.max)
//    #endif
//    
//    memcpy(&buffer, &number, 4)
//    
//    return buffer
//}

