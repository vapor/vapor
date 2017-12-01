import Async
import Bits
import Dispatch
import Foundation

/// Converts responses to Data.
public final class ResponseSerializer: Serializer {
    /// See InputStream.Input
    public typealias Input = HTTPResponse

    /// See OutputStream.Output
    public typealias Output = ByteBuffer
    
    /// When an upgrade request is in progress, this is set
    public private(set) var upgradeHandler: HTTPOnUpgrade?

    /// Use a basic stream to easily implement our output stream.
    var outputStream: BasicStream<Output>
    
    /// A buffer used to store writes in temporarily
    let writeBuffer: MutableBytesPointer
    
    /// A current data in the writeBuffer
    var writeBufferUsage: Int = 0
    
    /// The size of the above buffer
    let writeBufferSize: Int

    /// Create a new ResponseSerializer
    public init(bufferSize: Int = 65_535) {
        outputStream = .init()
        writeBufferSize = bufferSize
        writeBuffer = MutableBytesPointer.allocate(capacity: bufferSize)
    }

    /// See InputStream.onInput
    public func onInput(_ response: HTTPResponse) {
        var headers = response.headers
        
        if let count = response.body.count {
            headers[.contentLength] = count.description
        } else if case .stream(_) = response.body.storage {
            headers[.transferEncoding] = "chunked"
        }
        
        self.upgradeHandler = response.onUpgrade
        
        let statusCode = [UInt8](response.status.code.description.utf8)
        
        // First line
        let serialized = http1Prefix + statusCode + [.space] + response.status.messageBytes
        
        serialized.withUnsafeBufferPointer(write)
        headers.storage.withByteBuffer(write)
        
        // End of Headers
        crlf.withUnsafeBufferPointer(write)
        
        response.body.serialize(into: self)
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
    
    deinit {
        writeBuffer.deallocate(capacity: writeBufferSize)
    }
}

fileprivate let http1Prefix = [UInt8]("HTTP/1.1 ".utf8)
fileprivate let crlf = [UInt8]("\r\n".utf8)
fileprivate let headerKeyValueSeparator = [UInt8](": ".utf8)

// MARK: Utilities

