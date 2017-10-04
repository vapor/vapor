import Async
import Bits
import Foundation

final class RequestSerializer: Async.Stream {
    typealias Input = RedisValue
    typealias Output = ByteBuffer
    
    var onClose: BaseStream.CloseHandler?
    var errorStream: BaseStream.ErrorHandler?
    var outputStream: OutputHandler?

    init() {}
    
    func inputStream(_ input: RedisValue) {
        let message = input.serialize()
            
        message.withUnsafeBytes { (pointer: BytesPointer) in
            let buffer = ByteBuffer(start: pointer, count: message.count)
            outputStream?(buffer)
        }
    }
}

fileprivate let nullData = Data("$-1\r\n".utf8)

extension RedisValue {
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
