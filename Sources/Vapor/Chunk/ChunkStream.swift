/**
    Chunked transfer encoding is a data transfer mechanism in 
    version 1.1 of the Hypertext Transfer Protocol (HTTP) in which 
    data is sent in a series of "chunks". 
 
    the sender does not need to know
    the length of the content before it starts transmitting a response 
    to the receiver. Senders can begin transmitting dynamically-generated 
    content before knowing the total size of that content.
 
    https://en.wikipedia.org/wiki/Chunked_transfer_encoding
*/
public class ChunkStream: SendingStream {
    public let raw: SendingStream
    public var closed: Bool

    public init(stream: SendingStream) {
        self.raw = stream
        closed = false
    }

    public func send(_ int: Int) throws {
        try send("\(int)")
    }

    public func send(_ string: String) throws {
        try send(string.data)
    }

    public func send(_ data: Data) throws {
        try send(data, timingOut: 0)
    }

    public func send(_ data: Data, timingOut deadline: Double) throws {
        var buffer = "\(data.bytes.count)\r\n".data
        buffer.bytes += data.bytes
        buffer.bytes += "\r\n".data.bytes

        try raw.send(buffer, timingOut: deadline)
    }

    public func flush(timingOut deadline: Double) throws {
        try raw.flush()
    }

    public func close() throws {
        try raw.send("0\r\n\r\n") // stream should close by client
        closed = true
    }
}
