#warning("We should remove this when we don't need ByteBuffer")
public import NIOCore

extension ByteBuffer {
    public var string: String {
        .init(decoding: self.readableBytesView, as: UTF8.self)
    }
}

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

extension Data {
    public var string: String {
        .init(decoding: self, as: UTF8.self)
    }
}
