import Async
import libc
//
///// A type that can parse streaming query results
//protocol ResultsStream : OutputStream, ClosableStream {
//    /// Keeps track of all columns associated with the results
//    var columns: [Field] { get set }
//
//    /// Used to indicate the amount of returned columns
//    var columnCount: UInt64? { get set }
//
//    /// Keeps track of the server's protocol version for reading
//    var mysql41: Bool { get }
//
//    var onEOF: ((UInt16) throws -> ())? { get }
//
//    func parseRows(from packet: Packet) throws -> Output
//}

/// The "moreResultsExists" flag
///
/// TODO: Use this with cursor support

//extension ResultsStream {
//
//}

