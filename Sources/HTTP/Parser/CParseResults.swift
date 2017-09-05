import CHTTP
import Dispatch

/// The parse results object helps get around
/// the issue of not being able to capture context
/// with C closures.
///
/// All C closures must be sent some object that
/// this parse results object can be retreived from.
///
/// See the convenience methods below to see how the
/// object is set and fetched from the C object.
internal final class CParseResults {
    // state
    var headerState: HeaderState
    var isComplete: Bool

    // message components
    var version: Version?
    var headers: [Headers.Name: [String]]
    var body: DispatchData?
    var url: DispatchData?
    
    /// The maximum size of a request in bytes
    ///
    /// 10MB by default
    public let maximumSize: Int

    /// Creates a new results object
    init(maximumSize: Int = 10_000_000) {
        self.isComplete = false
        self.headers = [:]
        self.headerState = .none
        self.maximumSize = maximumSize
    }
}

// MARK: Convenience

extension CParseResults {
    /// Sets the parse results object on a C parser
    static func set(on parser: inout http_parser) -> CParseResults {
        let results = UnsafeMutablePointer<CParseResults>.allocate(capacity: 1)
        let new = CParseResults()
        results.initialize(to: new)
        parser.data = UnsafeMutableRawPointer(results)
        return new
    }

    static func remove(from parser: inout http_parser) {
        if let results = parser.data {
            let pointer = results.assumingMemoryBound(to: CParseResults.self)
            pointer.deinitialize()
            pointer.deallocate(capacity: 1)
        }
    }

    /// Fetches the parse results object from the C parser
    static func get(from parser: UnsafePointer<http_parser>?) -> CParseResults? {
        return parser?
            .pointee
            .data
            .assumingMemoryBound(to: CParseResults.self)
            .pointee
    }
}
