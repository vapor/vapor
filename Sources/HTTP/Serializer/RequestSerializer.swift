import Async
import Dispatch
import Foundation

/// Converts requests to DispatchData.
public final class RequestSerializer: Serializer {
    /// See InputStream.Input
    public typealias Input = Request

    /// See OutputStream.Output
    public typealias Notification = Data

    /// See OutputStream.outputStream
    public var outputStream: NotificationCallback?

    /// See BaseStream.errorNotification
    public let errorNotification = SingleNotification<Error>()

    /// Create a new RequestSerializer
    public init() {}

    /// Handles incoming requests.
    public func inputStream(_ input: Request) {
        let message = serialize(input)
        outputStream?(message)
    }

    /// Serializes a request into DispatchData.
    public func serialize(_ request: Request) -> Data {
        var serialized = request.method.data
        serialized.reserveCapacity(request.headers.storage.count + 256 + request.body.count)
        
        serialized.append(.space)
        serialized.append(contentsOf: request.uri.pathData)
        serialized.append(contentsOf: http1newLine)
        
        serialized.append(contentsOf: request.headers.storage)
        
        // Content-Length header
        serialized.append(contentsOf: Headers.Name.contentLength.original)
        serialized.append(.colon)
        serialized.append(.space)
        serialized.append(contentsOf: request.body.count.description.utf8)
        serialized.append(.carriageReturn)
        serialized.append(.newLine)
        
        // End of Headers
        serialized.append(.carriageReturn)
        serialized.append(.newLine)
        
        // Body
        switch request.body.storage {
        case .dispatchData(let data):
            serialized.append(contentsOf: data)
        case .data(let data):
            serialized.append(contentsOf: data)
        case .staticString(let string):
            let buffer = UnsafeBufferPointer(start: string.utf8Start, count: string.utf8CodeUnitCount)
            
            serialized.append(contentsOf: buffer)
        }
        
        return serialized
    }
}

fileprivate let http1newLine = Data(" HTTP/1.1\r\n".utf8)
