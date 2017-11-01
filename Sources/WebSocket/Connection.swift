import Bits
import Async
import Dispatch
import HTTP
import TCP

/// Manages frames to and from a TCP connection
internal final class Connection: Async.Stream, ClosableStream {
    /// Sends the closing frame and closes the connection
    func close() {
        do {
            let frame = try Frame(op: .close, payload: ByteBuffer(start: nil, count: 0), mask: serverSide ? nil : randomMask(), isFinal: true)
            
            self.inputStream(frame)
            self.client.close()
        } catch {
            errorNotification.notify(of: error)
        }
    }
    
    /// See `InputStream.Input`
    typealias Input = Frame
    
    /// See `OutputStream.Notification`
    typealias Notification = Frame

    /// The incoming frames handler
    ///
    /// See `OutputStream.outputStream`
    var outputStream: NotificationCallback?
    
    /// See `BaseStream.erorStream`
    let errorNotification = SingleNotification<Error>()
    
    /// Called when the connection closes
    var onClose: CloseHandler? {
        get {
            return self.client.onClose
        }
        set {
            self.client.onClose = newValue
        }
    }
    
    /// Serializes data into frames
    let serializer: FrameSerializer
    
    /// Defines the side of the socket
    ///
    /// Server side Sockets don't use masking
    let serverSide: Bool

    /// The underlying TCP connection
    let client: TCPClient
    
    /// Creates a new WebSocket Connection manager for a TCP.Client
    ///
    /// `serverSide` is used to determine if sent frames need to be masked
    init(client: TCPClient, serverSide: Bool = true) {
        self.client = client
        self.serverSide = serverSide
        
        let parser = FrameParser()
        serializer = FrameSerializer(masking: !serverSide)
        
        // Streams incoming data into the parser which sends it to this frame's handler
        client.stream(to: parser).drain { frame in
            self.outputStream?(frame)
        }
        
        // Streams outgoing data to the serializer, which sends it over the socket
        serializer.drain { buffer in
            let buffer = UnsafeRawBufferPointer(buffer)
            client.inputStream(DispatchData(bytes: buffer))
        }
    }

    func inputStream(_ input: Frame) {
        serializer.inputStream(input)
    }
}
