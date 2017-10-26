import Async
import Dispatch
import Foundation

/// Converts responses to Dispatch Data.
public final class ResponseSerializer: Serializer {
    /// See InputStream.Input
    public typealias Input = Response

    /// See OutputStream.Output
    public typealias Output = Data

    /// See OutputStream.outputStream
    public var outputStream: OutputHandler?

    /// See BaseStream.errorStream
    public var errorStream: ErrorHandler?

    /// Create a new ResponseSerializer.
    public init() {}

    /// Handles incoming responses.
    public func inputStream(_ input: Response) {
        let message = serialize(input)
        outputStream?(message)
    }

    /// Serializes a response into DispatchData.
    public func serialize(_ response: Response) -> Data {
        var serialized = Data()
        
        let statusLineData = serialize(response.status)
        let headersData = serialize(response.headers)
        let bodyData = serialize(response.body)
        
        serialized.reserveCapacity(statusLineData.count + headersData.count + bodyData.count)
        
        serialized.append(contentsOf: statusLineData)
        serialized.append(contentsOf: headersData)
        serialized.append(contentsOf: bodyData)
        
        return serialized
    }

    /// Handles http response status serialization.
    private func serialize(_ status: Status) -> Data {
        return Data("HTTP/1.1 \(status.code.description) \(status.message)\r\n".utf8)
    }
}

internal let eol = Data("\r\n".utf8)
internal let headerKeyValueSeparator: Data = Data(": ".utf8)

// MARK: Utilities

