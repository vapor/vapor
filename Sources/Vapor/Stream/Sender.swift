//extension Stream {
//    var sender: Sender {
//        return Sender(stream: self)
//    }
//}
//
///**
//    Wraps a Vapor.Stream as a C7.SendingStream.
//*/
//class Sender: SendingStream {
//    let stream: Stream
//
//    init(stream: Stream) {
//        self.stream = stream
//    }
//
//    var closed: Bool {
//        return stream.closed
//    }
//
//    func close() throws {
//        try stream.close()
//    }
//
//    func send(_ data: Data, timingOut deadline: Double) throws {
//        try stream.setTimeout(deadline)
//        try stream.send(data.bytes)
//    }
//
//    func flush(timingOut deadline: Double) throws {
//        try stream.setTimeout(deadline)
//        try stream.flush()
//    }
//    
//}
