import Async
import Bits
import Dispatch
import Foundation

/// Internal Swift HTTP serializer protocol.
public protocol HTTPSerializer: class {
    /// The message the parser handles.
    associatedtype Message: HTTPMessage

    /// The message being serialized.
    /// Becomes `nil` after completely serialized.
    /// Setting this property resets the serializer.
    var message: Message? { get set }

    /// Serializes data from the supplied message into the buffer.
    /// Returns the number of bytes serialized.
    func serialize(into buffer: MutableByteBuffer) throws -> Int
}
