import Foundation

public struct QueryLog {
    /// The time the query was logged
    public var time: Date
    
    /// Output of the log
    public var log: String
    
    /// Create a log from a raw log string.
    init(_ raw: String) {
        time = Date()
        log = raw
    }
    
    /// Create a log from raw sql and values.
    init(_ statement: String, _ values: [Node] = []) {
        var log = statement
        if values.count > 0 {
            let valuesString = values.map({ $0.string ?? "" }).joined(separator: ", ")
            log += " [\(valuesString)]"
        }
        self.init(log)
    }
}

extension QueryLog: CustomStringConvertible {
    public var description: String {
        return "[\(time)] \(log)"
    }
}

public protocol QueryLogger: class {
    func log(_ statement: String, _ values: [Node])
}
