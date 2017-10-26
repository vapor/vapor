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
        var serialized = Data()
        
        let requestLine = serialize(method: request.method, uri: request.uri)
        let headersData = serialize(request.headers)
        let bodyData = serialize(request.body)
        
        serialized.reserveCapacity(requestLine.count + headersData.count + bodyData.count)
        
        serialized.append(contentsOf: requestLine)
        serialized.append(contentsOf: headersData)
        serialized.append(contentsOf: bodyData)
        
        return serialized
    }

    /// Handles http request method serialization
    private func serialize(method: Method, uri: URI) -> Data {
        return Data("\(method.string) \(uri.path) HTTP/1.1\r\n".utf8)
    }
}
