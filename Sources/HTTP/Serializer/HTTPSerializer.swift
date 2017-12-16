import Async
import Bits
import Dispatch
import Foundation

/// A helper for Request and Response serializer that keeps state
internal enum State {
    case noMessage
    case firstLine
    case headers
    
    mutating func next() {
        if self == .firstLine {
            self = .headers
        } else {
            self = .noMessage
        }
    }
}

/// Internal Swift HTTP serializer protocol.
public protocol HTTPSerializer: class {
    /// The message the parser handles.
    associatedtype Message: HTTPMessage
    
    /// Indicates that the message headers have been flushed (and this serializer is ready)
    var ready: Bool { get }

    /// Sets the message being serialized.
    /// Becomes `nil` after completely serialized.
    /// Setting this property resets the serializer.
    func setMessage(to message: Message)

    /// Serializes data from the supplied message into the buffer.
    /// Returns the number of bytes serialized.
    func serialize(into buffer: MutableByteBuffer) throws -> Int
}

internal protocol _HTTPSerializer: HTTPSerializer {
    /// Serialized message
    var firstLine: [UInt8]? { get set }
    
    /// Headers
    var headersData: Data? { get set }
    
    /// The current offset of the currently serializing entity
    var offset: Int { get set }
    
    /// Keeps track of the state of serialization
    var state: State { get set }
}

extension _HTTPSerializer {
    /// Indicates that the message headers have been flushed (and this serializer is ready)
    public var ready: Bool {
        return self.state == .noMessage
    }
    
    /// See HTTPSerializer.serialize
    public func serialize(into buffer: MutableByteBuffer) throws -> Int {
        let bufferSize: Int
        let writeSize: Int
        
        switch state {
        case .noMessage:
            throw HTTPError(identifier: "no-response", reason: "Serialization requested without a response")
        case .firstLine:
            guard let firstLine = self.firstLine else {
                throw HTTPError(identifier: "invalid-state", reason: "Missing first line metadata")
            }
            
            bufferSize = firstLine.count
            writeSize = min(buffer.count, bufferSize - offset)
            
            firstLine.withUnsafeBytes { pointer in
                _ = memcpy(buffer.baseAddress!, pointer.baseAddress!.advanced(by: offset), writeSize)
            }
        case .headers:
            guard let headersData = self.headersData else {
                throw HTTPError(identifier: "invalid-state", reason: "Missing header state")
            }
            
            bufferSize = headersData.count
            writeSize = min(buffer.count, bufferSize - offset)
            
            headersData.withByteBuffer { headerBuffer in
                buffer.baseAddress?.assign(from: headerBuffer.baseAddress!.advanced(by: offset), count: writeSize)
            }
        }
        
        if offset + writeSize < bufferSize {
            offset += writeSize
        } else {
            state.next()
            offset = 0
        }
        
        return writeSize
    }
}
