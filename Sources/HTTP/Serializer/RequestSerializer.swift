import Async
import Dispatch
import Foundation

/// Converts requests to DispatchData.
public final class RequestSerializer: Serializer {
    /// See InputStream.Input
    public typealias Input = Request

    /// See OutputStream.Output
    public typealias Output = Data

    /// Use a basic stream to easily implement our output stream.
    private var outputStream: BasicStream<Output>

    /// Create a new RequestSerializer
    public init() {
        outputStream = .init()
    }

    /// See InputStream.onInput
    public func onInput(_ input: Request) {
        let message = serialize(input)
        outputStream.onInput(message)
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
    public func close() {
        outputStream.close()
    }

    /// See CloseableStream.onClose
    public func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
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
