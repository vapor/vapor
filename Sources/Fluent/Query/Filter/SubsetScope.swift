/// Describes the methods for comparing
/// a field to a set of values.
/// Think of it like Swift's `.contains`.
public enum QuerySubsetScope {
    case `in`
    case notIn
}

/// Describes the values a subset can have.
/// The subset can be either an array of encodable
/// values or another query whose purpose
/// is to yield an array of values.
public enum QuerySubsetValue {
    case array([Encodable])
    case subquery(DatabaseQuery)
}
