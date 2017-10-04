public typealias Byte = UInt8
public typealias Bytes = [Byte]
public typealias ByteBuffer = UnsafeBufferPointer<Byte>
public typealias MutableByteBuffer = UnsafeMutableBufferPointer<Byte>
public typealias BytesPointer = UnsafePointer<Byte>
public typealias MutableBytesPointer = UnsafeMutablePointer<Byte>

public func ~=(pattern: Byte, value: Byte?) -> Bool {
    return pattern == value
}

extension Byte {
    public var string: String {
        let unicode = Unicode.Scalar(self)
        let char = Character(unicode)
        return String(char)
    }
}
