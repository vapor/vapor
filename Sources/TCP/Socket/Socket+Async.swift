import Dispatch

/// A socket event.
public typealias SocketEvent = () -> ()

extension Socket {
//    /// The socket event will be called on the supplied queue
//    /// whenever this socket can be read from.
//    public func onReadable(queue: DispatchQueue, event: @escaping SocketEvent) -> DispatchSourceRead {
//        let source = DispatchSource.makeReadSource(
//            fileDescriptor: descriptor.raw,
//            queue: queue
//        )
//        source.setEventHandler {
//            event()
//        }
//        source.resume()
//        return source
//    }
//
//
//    /// The socket event will be called on the supplied queue
//    /// whenever this socket can be written to.
//    public func onWriteable(queue: DispatchQueue, event: @escaping SocketEvent) -> DispatchSourceWrite {
//        let source = DispatchSource.makeWriteSource(
//            fileDescriptor: descriptor.raw,
//            queue: queue
//        )
//        source.setEventHandler {
//            event()
//        }
//        source.resume()
//        return source
//    }
}
