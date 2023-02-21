import NIOCore

extension ByteBuffer {
    init(string: String) {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeString(string)
        self = buffer
    }
}
