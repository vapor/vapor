import Async
import Dispatch
import Foundation

/// Converts requests to DispatchData.
public final class RequestSerializer: Serializer {
    /// See InputStream.Input
    public typealias Input = Request

    /// See OutputStream.Output
    public typealias Output = DispatchData

    /// See OutputStream.outputStream
    public var outputStream: OutputHandler?

    /// See BaseStream.errorStream
    public var errorStream: ErrorHandler?

    /// Create a new RequestSerializer
    public init() {}

    /// Handles incoming requests.
    public func inputStream(_ input: Request) {
        let response = serialize(input)
        outputStream?(response)
    }

    /// Serializes a request into DispatchData.
    public func serialize(_ request: Request) -> DispatchData {
        var serialized = serialize(method: request.method, uri: request.uri)

        serialized.append(serialize(request.headers))

        serialized.append(serialize(request.body))

        return serialized
    }

    /// Handles http request method serialization
    private func serialize(method: Method, uri: URI) -> DispatchData {
        return DispatchData("\(method.string) \(uri.path) HTTP/1.1\r\n")
    }
}
