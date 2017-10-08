import Async
import Dispatch
import Foundation

/// Converts requests to DispatchData.
public final class RequestSerializer: Serializer {
    /// See InputStream.Input
    public typealias Input = Request

    /// See OutputStream.Output
    public typealias Output = SerializedMessage

    /// See OutputStream.outputStream
    public var outputStream: OutputHandler?

    /// See BaseStream.errorStream
    public var errorStream: ErrorHandler?

    /// Create a new RequestSerializer
    public init() {}

    /// Handles incoming requests.
    public func inputStream(_ input: Request) {
        let data = serialize(input)
        let message = SerializedMessage(message: data, onUpgrade: input.onUpgrade)
        outputStream?(message)
    }

    /// Serializes a request into DispatchData.
    public func serialize(_ request: Request) -> DispatchData {
        var serialized = serialize(method: request.method, uri: request.uri)

        let iterator = request.headers.makeIterator()
        while let header = iterator.next() {
            let data = serialize(header: header.name, value: header.value)
            serialized.append(data)
        }
        serialized.append(eol)

        let body = serialize(request.body)
        serialized.append(body)

        return serialized
    }

    /// Handles http request method serialization
    private func serialize(method: Method, uri: URI) -> DispatchData {
        return DispatchData("\(method.string) \(uri.path) HTTP/1.1\r\n")
    }
}
