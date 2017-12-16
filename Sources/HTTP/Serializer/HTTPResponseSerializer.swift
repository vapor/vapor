import Async
import Bits
import Dispatch
import Foundation

/// Converts responses to Data.
public final class HTTPResponseSerializer: _HTTPSerializer {
    /// See HTTPSerializer.Message
    public typealias Message = HTTPResponse

    /// Serialized message
    var firstLine: [UInt8]?
    
    /// Headers
    var headersData: Data?

    /// The current offset
    var offset: Int
    
    /// The current serialization taking place
    var state = State.noMessage {
        didSet {
            switch self.state {
            case .headers:
                self.firstLine = nil
            case .noMessage:
                self.headersData = nil
                self.firstLine = nil
            default: break
            }
        }
    }

    /// Create a new HTTPResponseSerializer
    public init() {
        offset = 0
    }
    
    /// Set up the variables for Message serialization
    public func setMessage(to message: Message) {
        offset = 0
        
        self.state = .firstLine
        var headers = message.headers
        
        switch message.body.storage {
        case .outputStream:
            headers[.transferEncoding] = "chunked"
        case .data, .dispatchData, .staticString, .string:
            headers[.contentLength] = message.body.count.description
        }
        
        self.firstLine = message.firstLine
        self.headersData = headers.storage + crlf
    }
}

fileprivate extension HTTPResponse {
    var firstLine: [UInt8] {
        // First line
        let statusCode = [UInt8](self.status.code.description.utf8)
        return http1Prefix + statusCode + [.space] + self.status.messageBytes + crlf
    }
}

private let http1Prefix = [UInt8]("HTTP/1.1 ".utf8)
private let crlf = [UInt8]("\r\n".utf8)
private let headerKeyValueSeparator = [UInt8](": ".utf8)
