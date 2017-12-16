import Async
import Bits
import Dispatch
import Foundation

/// Converts requests to DispatchData.
public final class HTTPRequestSerializer: _HTTPSerializer {
    public typealias Message = HTTPRequest
    
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

    /// Create a new HTTPRequestSerializer
    public init() {
        offset = 0
    }
}

fileprivate extension HTTPRequest {
    var firstLine: [UInt8] {
        var firstLine = self.method.bytes
        firstLine.reserveCapacity(self.headers.storage.count + 256)
        
        firstLine.append(.space)
        
        if self.uri.pathBytes.first != .forwardSlash {
            firstLine.append(.forwardSlash)
        }
        
        firstLine.append(contentsOf: self.uri.pathBytes)
        
        if let query = self.uri.query {
            firstLine.append(.questionMark)
            firstLine.append(contentsOf: query.utf8)
        }
        
        if let fragment = self.uri.fragment {
            firstLine.append(.numberSign)
            firstLine.append(contentsOf: fragment.utf8)
        }
        
        return firstLine + http1newLine
    }
}

fileprivate let crlf = Data([
    .carriageReturn,
    .newLine
])
fileprivate let http1newLine = [UInt8](" HTTP/1.1\r\n".utf8)
