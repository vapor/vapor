import C7

/**
    Buffers receive and send calls to a Stream.
 
    Receive calls are buffered by the size used to initialize
    the buffer.
 
    Send calls are buffered until `flush()` is called.
*/
public final class StreamBuffer: Stream {
    public var closed: Bool {
        return stream.closed
    }
    public func close() throws {
        try stream.close()
    }

    private let stream: Stream
    private let size: Int

    public var timeout: Double {
        get {
            return stream.timeout
        }
        set {
            stream.timeout = newValue
        }
    }

    private var receiveIterator: IndexingIterator<[Byte]>
    private var sendBuffer: Bytes

    public init(_ stream: Stream, size: Int = 2048) {
        self.size = size
        self.stream = stream

        self.receiveIterator = Data().makeIterator()
        self.sendBuffer = []

        timeout = 0
    }

    public func receive() throws -> Byte? {
        guard let next = receiveIterator.next() else {
            receiveIterator = try stream.receive(max: size).makeIterator()
            return receiveIterator.next()
        }
        return next
    }

    public func receive(max: Int) throws -> Bytes {
        var bytes: Bytes = []

        for _ in 0 ..< max {
            guard let byte = try receive() else {
                break
            }

            bytes += byte
        }

        return bytes
    }

    public func send(_ bytes: Bytes) throws {
        sendBuffer += bytes
    }

    public func flush() throws {
        try stream.send(sendBuffer)
        sendBuffer = []
    }
}
