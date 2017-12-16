import Async
import Bits
import Dispatch
import Foundation

/// Converts responses to Data.
public final class HTTPResponseSerializer: HTTPSerializer {
    /// See HTTPSerializer.Message
    public typealias Message = HTTPResponse

    /// The message being serialized
    public var message: HTTPResponse? {
        didSet {
            dataOffset = 0
            data = nil
        }
    }

    /// Serialized message
    private var data: Data?

    /// The current offset
    private var dataOffset: Int

    /// Create a new HTTPResponseSerializer
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

    private func serialize(_ response: HTTPResponse) -> Data {
        var data = Data()
        var headers = response.headers

        switch response.body.storage {
        case .outputStream:
            headers[.transferEncoding] = "chunked"
        case .data, .dispatchData, .staticString, .string:
            headers[.contentLength] = response.body.count.description
        }

        let statusCode = [UInt8](response.status.code.description.utf8)
        
        // First line
        let serialized = http1Prefix + statusCode + [.space] + response.status.messageBytes + crlf
        
        data += serialized
        data += headers.storage
        
        // End of Headers
        data += crlf
        return data
    }
}

private let http1Prefix = [UInt8]("HTTP/1.1 ".utf8)
private let crlf = [UInt8]("\r\n".utf8)
private let headerKeyValueSeparator = [UInt8](": ".utf8)
