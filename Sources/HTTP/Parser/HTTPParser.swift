import Bits
import Foundation

/// HTTP message parser.
public protocol HTTPParser: class {
    /// The message the parser handles.
    associatedtype Message: HTTPMessage

    /// The parsed message.
    /// Becomes non-nil after completely parsed.
    /// Seeting this property to `nil` resets the parser.
    var message: Message? { get set }

    /// Parses data from the supplied buffer.
    /// Returns the number of bytes parsed.
    /// If the number of bytes parsed is 0, the parser is done.
    func parse(max: Int, from buffer: ByteBuffer) throws -> Int
}

//extension HTTPParser {
//    /// Parses request Data. If the data does not contain
//    /// an entire HTTP request, nil will be returned and
//    /// the parser will remain ready to accept new Data.
//    public func parse(from data: Data) throws -> Message? {
//        return try data.withUnsafeBytes { (pointer: BytesPointer) in
//            let buffer = ByteBuffer(start: pointer, count: data.count)
//            let parsed = try parse(max: buffer.count, from: buffer)
//            assert(parsed == buffer.count)
//            return message
//        }
//    }
//}

