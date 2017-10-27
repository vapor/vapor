import Async
import Dispatch
import Foundation

/// Converts requests to DispatchData.
public final class RequestSerializer: Serializer {
    /// See InputStream.Input
    public typealias Input = Request

    /// See OutputStream.Output
    public typealias Output = Data

    /// See OutputStream.outputStream
    public var outputStream: OutputHandler?

    /// See BaseStream.errorStream
    public var errorStream: ErrorHandler?

    /// Create a new RequestSerializer
    public init() {}

    /// Handles incoming requests.
    public func inputStream(_ input: Request) {
        let message = serialize(input)
        outputStream?(message)
    }

    /// Serializes a request into DispatchData.
    public func serialize(_ request: Request) -> Data {
        let requestLine = serialize(method: request.method, uri: request.uri)
        let bodyData = serialize(request.body)
        
        var serialized = Data()
        serialized.reserveCapacity(requestLine.count + request.headers.storage.count + 2 + bodyData.count)
        
        serialized.append(contentsOf: requestLine)
        serialized.append(contentsOf: request.headers.storage)
        
        // Content-Length header
        serialized.append(contentsOf: Headers.Name.contentLength.original)
        serialized.append(.colon)
        serialized.append(.space)
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

    /// Handles http request method serialization
    private func serialize(method: Method, uri: URI) -> Data {
        return Data("\(method.string) \(uri.path) HTTP/1.1\r\n".utf8)
    }
}
