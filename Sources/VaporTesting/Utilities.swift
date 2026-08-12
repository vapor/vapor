#warning("We should remove this when we don't need ByteBuffer")
public import NIOCore

extension ByteBuffer {
    public var string: String {
        .init(decoding: self.readableBytesView, as: UTF8.self)
    }
}
