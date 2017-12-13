import Foundation
import Async
import Bits

public protocol Base64 {
    func process(
        _ buffer: ByteBuffer,
        toPointer pointer: MutableBytesPointer,
        capacity: Int,
        finish: Bool
    ) throws -> (complete: Bool, filled: Int, consumed: Int)
    
    init(encoding: Base64Encoding, bufferCapacity: Int)
    
    /// The capacity currently used in the pointer
    var currentCapacity: Int { get set }
    
    /// The total capacity of the pointer
    var allocatedCapacity: Int { get }
    
    /// The pointer for containing the base64 encoded data
    var pointer: MutableBytesPointer { get }
}

extension Base64 {
    /// Creates a Base64 coder with default buffer size and encoding
    public init() {
        self.init(encoding: .base64)
    }

    /// Creates a base64 coder with supplied encoding and default buffer size
    public init(encoding: Base64Encoding) {
        self.init(encoding: encoding, bufferCapacity: 65_536)
    }

    /// Creates a base64 coder with default encoding and supplied buffer size
    public init(bufferCapacity: Int) {
        self.init(encoding: .base64, bufferCapacity: bufferCapacity)
    }
}

extension Base64 {
    /// Create a Base64Stream for this Base64 coder.
    public func stream() -> Base64Stream {
        return Base64Stream(base64: self)
    }
}
