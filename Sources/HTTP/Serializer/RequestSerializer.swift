import Async
import Bits
import Dispatch
import Foundation

/// Converts requests to DispatchData.
public final class RequestSerializer: Serializer {
    /// See InputStream.Input
    public typealias Input = HTTPRequest

    /// See OutputStream.Output
    public typealias Output = ByteBuffer

    /// Use a basic stream to easily implement our output stream.
    var outputStream: BasicStream<Output>
    
    /// A buffer used to store writes in temporarily
    let writeBuffer: MutableBytesPointer
    
    /// A current data in the writeBuffer
    var writeBufferUsage: Int = 0
    
    /// The size of the above buffer
    let writeBufferSize: Int

    /// Create a new RequestSerializer
    public init(bufferSize: Int = 65_535) {
        outputStream = .init()
        writeBufferSize = bufferSize
        writeBuffer = MutableBytesPointer.allocate(capacity: bufferSize)
    }
    
    /// See InputStream.onInput
    public func onInput(_ request: HTTPRequest) {
        var serialized = request.method.bytes
        serialized.reserveCapacity(request.headers.storage.count + 256)
        
        serialized.append(.space)
        serialized.append(contentsOf: request.uri.pathBytes)
        serialized.append(contentsOf: http1newLine)
        
        var headers = request.headers
        
        if let count = request.body.count {
            headers[.contentLength] = count.description
        } else if case .stream(_) = request.body.storage {
            headers[.transferEncoding] = "chunked"
        }
        
        serialized.withUnsafeBufferPointer(write)
        headers.storage.withByteBuffer(write)
        
        // End of Headers
        crlf.withByteBuffer(write)
        
        // Body
        request.body.serialize(into: self)
        self.flush()
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
}

fileprivate let crlf = Data([
    .carriageReturn,
    .newLine
])
fileprivate let http1newLine = [UInt8](" HTTP/1.1\r\n".utf8)
