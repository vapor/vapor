import Async
import Bits
import Foundation

/// A streaming Redis value serializer
final class DataSerializer: Async.Stream {
    /// See InputStream.Input
    typealias Input = RedisData
    
    /// See OutputStream.Output
    typealias Output = ByteBuffer

    /// Use a basic output stream to implement server output stream.
    internal var outputStream: BasicStream<Output> = .init()

    /// Creates a new ValueSerializer
    init() {}

    /// See InputStream.onInput
    public func onInput(_ input: RedisData) {
        let message = input.serialize()

        message.withUnsafeBytes { (pointer: BytesPointer) in
            let buffer = ByteBuffer(start: pointer, count: message.count)
            outputStream.onInput(buffer)
        }
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    public func onOutput<I>(_ input: I) where I: Async.InputStream, Output == I.Input {
        outputStream.onOutput(input)
    }

    /// See CloseableStream.close
    func close() {
        outputStream.close()
    }

    /// See CloseableStream.onClose
    func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
    }
}

extension DataSerializer {
    /// Used for pipelining commands
    /// Concatenates commands to RedisData for the outputStream
    func onInput(_ input: [RedisData]) {
        /// FIXME: should we make a `PipelinedDataSerializer` that properly conforms?
        var buffer = Data()
        for item in input {
            buffer.append(contentsOf: item.serialize())
        }
        buffer.withUnsafeBytes { (pointer: BytesPointer) in
            let buffer = ByteBuffer(start: pointer, count: buffer.count)
            outputStream.onInput(buffer)
        }
    }
    
}

/// Static "fast" route for serializing `null` values
fileprivate let nullData = Data("$-1\r\n".utf8)

extension RedisData {
    /// Serializes a single value
    func serialize() -> Data {
        switch self.storage {
        case .null:
            return nullData
        case .basicString(let string):
            return Data(("+" + string).utf8)
        case .error(let error):
            return Data(("-" + error.reason).utf8)
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
