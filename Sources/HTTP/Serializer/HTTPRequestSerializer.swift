import Async
import Bits
import Dispatch
import Foundation

/// Converts requests to DispatchData.
public final class HTTPRequestSerializer: HTTPSerializer {
    /// See HTTPSerializer.Message
    public typealias Message = HTTPRequest

    /// The message being serialized
    public var message: HTTPRequest? {
        didSet {
            dataOffset = 0
            data = nil
        }
    }

    /// Serialized message
    private var data: Data?

    /// The current offset
    private var dataOffset: Int

    /// Create a new HTTPRequestSerializer
    public init() {
        dataOffset = 0
    }

    /// See HTTPSerializer.serialize
    public func serialize(into buffer: MutableByteBuffer) throws -> Int {
        let data: Data
        if let existing = self.data {
            data = existing
        } else {
            let new = serialize(message!)
            self.dataOffset = 0
            self.data = new
            data = new
        }

        let remaining = data.count - dataOffset
        let num = remaining > buffer.count ? buffer.count : remaining
        data.copyBytes(to: buffer.baseAddress!, from: dataOffset..<dataOffset + num)
        dataOffset = dataOffset + num

        if dataOffset == data.count {
            message = nil
        }
        
        return num
    }

    private func serialize(_ request: HTTPRequest) -> Data {
        var data = Data()

        var serialized = request.method.bytes
        serialized.reserveCapacity(request.headers.storage.count + 256)

        serialized.append(.space)

        if request.uri.pathBytes.first != .forwardSlash {
            serialized.append(.forwardSlash)
        }

        serialized.append(contentsOf: request.uri.pathBytes)

        if let query = request.uri.query {
            serialized.append(.questionMark)
            serialized.append(contentsOf: query.utf8)
        }

        if let fragment = request.uri.fragment {
            serialized.append(.numberSign)
            serialized.append(contentsOf: fragment.utf8)
        }

        serialized.append(contentsOf: http1newLine)

        var headers = request.headers
        switch request.body.storage {
        case .outputStream:
            headers[.transferEncoding] = "chunked"
        case .data, .dispatchData, .staticString, .string:
            headers[.contentLength] = request.body.count.description
        }

        data += serialized
        data += headers.storage

        // End of Headers
        data += crlf
        return data
    }
}

fileprivate let crlf = Data([
    .carriageReturn,
    .newLine
])
fileprivate let http1newLine = [UInt8](" HTTP/1.1\r\n".utf8)
