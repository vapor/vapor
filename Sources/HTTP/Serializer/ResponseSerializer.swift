import Async
import Bits
import Dispatch
import Foundation

/// Converts responses to Data.
public final class ResponseSerializer: Serializer {
    /// See InputStream.Input
    public typealias Input = Response

    /// See OutputStream.Output
    public typealias Notification = Data

    /// See OutputStream.outputStream
    public var outputStream: NotificationCallback?

    /// See BaseStream.errorNotification
    public let errorNotification = SingleNotification<Error>()
    
    /// When an upgrade request is in progress, this is set
    public private(set) var upgradeHandler: OnUpgrade?

    /// Create a new ResponseSerializer.
    public init() {}

    /// Handles incoming responses.
    public func inputStream(_ input: Response) {
        let message = serialize(input)
        outputStream?(message)
    }

    /// Efficiently serializes a response into Data.
    public func serialize(_ response: Response) -> Data {
        self.upgradeHandler = response.onUpgrade
        
        let statusCode = Data(response.status.code.description.utf8)
        let contentLength = Data(response.body.count.description.utf8)
        
        let contentLengthLength = Headers.Name.contentLength.original.count + headerKeyValueSeparator.count + contentLength.count + eol.count
        
        // prefix + status + space + message + eol
        let firstLineCount = http1Prefix.count + statusCode.count + 1 + response.status.messageData.count + eol.count
        
        // first line + headers + contentLengthHeader + EOL + body + EOL
        let messageSize = firstLineCount + response.headers.storage.count + contentLengthLength + eol.count + response.body.count
        
        var data = Data(repeating: 0, count: messageSize)
        
        data.withUnsafeMutableBytes { (message: MutableBytesPointer) in
            var offset = 0
            
            // First line
            offset += copy(http1Prefix, to: message)
            offset += copy(statusCode, to: message.advanced(by: offset))
            message.advanced(by: offset).pointee = .space
            offset += 1
            offset += copy(response.status.messageData, to: message.advanced(by: offset))
            offset += copy(eol, to: message.advanced(by: offset))
            
            // headers
            offset += copy(response.headers.storage, to: message.advanced(by: offset))
            
            // Content-Length
            offset += copy(Headers.Name.contentLength.original, to: message.advanced(by: offset))
            offset += copy(headerKeyValueSeparator, to: message.advanced(by: offset))
            offset += copy(contentLength, to: message.advanced(by: offset))
            offset += copy(eol, to: message.advanced(by: offset))
            
            // End of headers
            offset += copy(eol, to: message.advanced(by: offset))
            
            switch response.body.storage {
            case .data(let data):
                offset += copy(data, to: message.advanced(by: offset))
            case .dispatchData(let data):
                offset += copy(Data(data), to: message.advanced(by: offset))
            case .staticString(let pointer):
                memcpy(message.advanced(by: offset), pointer.utf8Start, pointer.utf8CodeUnitCount)
            }
        }
        
        return data
    }
}

fileprivate func copy(_ data: Data, to pointer: MutableBytesPointer) -> Int {
    data.withUnsafeBytes { (dataPointer: BytesPointer) in
        _ = memcpy(pointer, dataPointer, data.count)
    }
    
    return data.count
}

internal let http1Prefix = Data("HTTP/1.1 ".utf8)
internal let eol = Data("\r\n".utf8)
internal let headerKeyValueSeparator: Data = Data(": ".utf8)

// MARK: Utilities

