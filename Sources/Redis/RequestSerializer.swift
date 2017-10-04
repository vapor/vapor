import Async
import Bits
import Foundation

/// A streaming Redis value serializer
final class ValueSerializer: Async.Stream {
    /// See `InputStream.Input`
    typealias Input = RedisValue
    
    /// See `OutputStream.Output`
    typealias Output = ByteBuffer
    
    /// See `BaseStream.onClose`
    var onClose: BaseStream.CloseHandler?
    
    /// See `BaseStream.errorStream`
    var errorStream: BaseStream.ErrorHandler?
    
    /// See `OutputStream.outputStream`
    var outputStream: OutputHandler?

    /// Creates a new ValueSerializer
    init() {}
    
    /// Serializes a value to the outputStream
    func inputStream(_ input: RedisValue) {
        let message = input.serialize()
            
        message.withUnsafeBytes { (pointer: BytesPointer) in
            let buffer = ByteBuffer(start: pointer, count: message.count)
            outputStream?(buffer)
        }
    }
}

/// Static "fast" route for serializing `null` values
fileprivate let nullData = Data("$-1\r\n".utf8)

extension RedisValue {
    /// Serializes a single value
    func serialize() -> Data {
        switch self {
        case .null:
            return nullData
        case .basicString(let string):
            return Data(("+" + string).utf8)
        case .error(let error):
            return Data(("-" + error.string).utf8)
        case .integer(let int):
            return Data(":\(int)\r\n".utf8)
        case .bulkString(let data):
            return Data("$\(data.count)\r\n".utf8) + data + Data("\r\n".utf8)
        case .array(let values):
            var buffer = Data("*\(values.count)\r\n".utf8)
            for value in values {
                buffer.append(contentsOf: value.serialize())
            }
            buffer.append(contentsOf: Data("\r\n".utf8))
            return buffer
        }
    }
}
