import Core
import Dispatch
import Foundation

/// Converts responses to Dispatch Data.
public final class ResponseSerializer: Serializer {
    /// See InputStream.Input
    public typealias Input = Response

    /// See OutputStream.Output
    public typealias Output = SerializedMessage

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
        
        serialized.append(serialize(response.headers))
        
        serialized.append(serialize(response.body))

        return serialized
    }

    /// Handles http response status serialization.
    private func serialize(_ status: Status) -> DispatchData {
        return DispatchData("HTTP/1.1 \(status.code.description) \(status.message.utf8)\r\n")
    }
}

internal let eol = Data("\r\n".utf8)
internal let headerKeyValueSeparator: Data = Data(": ".utf8)

// MARK: Utilities

