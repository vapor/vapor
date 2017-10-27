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
        let bodyData = serialize(response.body)
        
        var serialized = Data()
        
        // Reserve 128 bytes for the content length and first line
        serialized.reserveCapacity(response.headers.storage.count + bodyData.count + 512)
        
        // HTTP first response line
        serialized.append(contentsOf: http1Prefix)
        serialized.append(contentsOf: response.status.code.description.utf8)
        serialized.append(.space)
        serialized.append(contentsOf: response.status.message.utf8)
        serialized.append(.carriageReturn)
        serialized.append(.newLine)
        
        serialized.append(contentsOf: response.headers.storage)
        
        // Content-Length header
        serialized.append(contentsOf: Headers.Name.contentLength.original)
        serialized.append(contentsOf: headerKeyValueSeparator)
        serialized.append(contentsOf: bodyData.count.description.utf8)
        serialized.append(.carriageReturn)
        serialized.append(.newLine)
        
        // End of Headers
        serialized.append(.carriageReturn)
        serialized.append(.newLine)
        
        // Body
        serialized.append(contentsOf: bodyData)
        
        return serialized
    }
}

internal let http1Prefix = Data("HTTP/1.1 ".utf8)
internal let eol = Data("\r\n".utf8)
internal let headerKeyValueSeparator: Data = Data(": ".utf8)

// MARK: Utilities

