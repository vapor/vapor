import Core
import Dispatch
import Foundation

/// Converts responses to Dispatch Data.
public final class ResponseSerializer: Serializer {
    /// See InputStream.Input
    public typealias Input = Response

    /// See OutputStream.Output
    public typealias Output = SerializedMessage
    
    /// See `BaseStream.onClose`
    public var onClose: CloseHandler?

    /// See OutputStream.outputStream
    public var outputStream: OutputHandler?

    /// See BaseStream.errorStream
    public var errorStream: ErrorHandler?

    /// Create a new ResponseSerializer.
    public init() {}

    /// Handles incoming responses.
    public func inputStream(_ input: Response) {
        let data = serialize(input)
        let message = SerializedMessage(message: data, onUpgrade: input.onUpgrade)
        outputStream?(message)
    }

    /// Serializes a response into DispatchData.
    public func serialize(_ response: Response) -> DispatchData {
        var serialized = serialize(response.status)

        let iterator = response.headers.makeIterator()
        while let header = iterator.next() {
            let data = serialize(header: header.name, value: header.value)
            serialized.append(data)
        }
        serialized.append(eol)

        let body = serialize(response.body)
        serialized.append(body)

        return serialized
    }

    /// Handles http response status serialization.
    private func serialize(_ status: Status) -> DispatchData {
        switch status {
        case .upgrade:
            return Signature.upgrade
        case .ok:
            return Signature.ok
        case .notFound:
            return Signature.notFound
        case .internalServerError:
            return Signature.internalServerError
        case .custom(let code, let message):
            return DispatchData("HTTP/1.1 \(code.description) \(message.utf8)\r\n")
        }
    }
}

// MARK: Utilities

fileprivate enum Signature {
    static let internalServerError = DispatchData("HTTP/1.1 500 Internal Server Error\r\n")
    static let upgrade = DispatchData("HTTP/1.1 101 Switching Protocols\r\n")
    static let ok = DispatchData("HTTP/1.1 200 OK\r\n")
    static let notFound = DispatchData("HTTP/1.1 404 Not Found\r\n")
}
