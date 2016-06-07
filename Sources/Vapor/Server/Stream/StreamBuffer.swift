import C7

/**
    Stream buffer wraps a stream and then acts as a stream itself to get access to single bytes 
    as an iterator without as much of a performance hit on the underlying stream.
 
    StreamBuffer itsself conforms to stream and can be used as such.
*/
public final class StreamBuffer {
    private let backingStream: Stream
    private let buffer: Int

    private var iterator: IndexingIterator<[Byte]>

    public init(_ stream: Stream, buffer: Int = 1024) {
        self.backingStream = stream
        self.buffer = buffer
        self.iterator = Data().makeIterator()
    }

    public func next() throws -> Byte? {
        guard let next = iterator.next() else {
            iterator = try backingStream.receive(upTo: buffer).makeIterator()
            return iterator.next()
        }
        return next
    }

    public func chunk(size: Int) throws -> [Byte] {
        var count = 0
        var bytes = [Byte].init(repeating: 0, count: size)
        while count < size, let byte = try next() {
            bytes[count] = byte
            count += 1
        }
        return bytes
    }
}


extension StreamBuffer: Stream {}

extension StreamBuffer: Closable {
    public var closed: Bool {
        return backingStream.closed
    }
    public func close() throws {
        try backingStream.close()
    }
}

extension StreamBuffer: Sending {
    public func send(_ data: Data, timingOut deadline: Double) throws {
        try backingStream.send(data, timingOut: deadline)
    }

    public func flush(timingOut deadline: Double) throws {
        try backingStream.flush(timingOut: deadline)
    }
}

extension StreamBuffer: Receiving {
    public func receive(upTo byteCount: Int, timingOut deadline: Double) throws -> Data {
        return try Data(chunk(size: byteCount))
    }
}