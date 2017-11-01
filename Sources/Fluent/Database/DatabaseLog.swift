import Foundation

/// Represents a database log.
public struct DatabaseLog: CustomStringConvertible {
    /// Database identifier
    var dbID: String

    /// A string representing the query
    var query: String

    /// An array of strings reprensenting the values.
    var values: [String]

    /// The time the log was created
    var date: Date

    /// See CustomStringConvertible.description
    public var description: String {
        return "[\(dbID)] [\(date)] \(query) \(values)"
    }

    /// Create a new database log.
    init(query: String, values: [String] = [], dbID: String = "fluent", date: Date = Date()) {
        self.query = query
        self.values = values
        self.date = date
        self.dbID = dbID
    }
}

