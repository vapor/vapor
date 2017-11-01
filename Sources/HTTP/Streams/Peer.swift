import Async
import Bits
import TCP
import Foundation

/// An HTTP `Server`'s peer wrapped around TCP client
public final class Peer: Async.Stream, ClosableStream {
    /// See `InputStream.Input`
    public typealias Input = Data
    
    /// See `OutputStream.Notification`
    public typealias Notification = ByteBuffer
    
    /// See `BaseStream.onClose`
    public var onClose: CloseHandler? {
        get {
            return tcp.onClose
        }
        set {
            tcp.onClose = newValue
        }
    }
    
    /// See `OutputStream.NotificationCallback`
    public var outputStream: NotificationCallback? {
        get {
            return tcp.outputStream
        }
        set {
            tcp.outputStream = newValue
        }
    }
    
    /// See `OutputStream.errorStream`
    public let errorNotification = SingleNotification<Error>()
    
    /// The underlying TCP Client
    public let tcp: TCPClient
    
    /// Creates a new `Peer` from a `TCP.Client`
    public init(tcp: TCPClient) {
        self.tcp = tcp
    }
    
    /// Writes the serialized message and upgrades if necessary
    public func inputStream(_ input: Data) {
        tcp.inputStream(input)
    }
    
    public func close() {
        tcp.close()
    }
}
