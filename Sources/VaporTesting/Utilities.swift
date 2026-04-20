import NIOCore

extension ByteBuffer {
    public var string: String {
        .init(decoding: self.readableBytesView, as: UTF8.self)
    }
}
