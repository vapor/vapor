/// Each database in your application receives its own identifier.
/// Your main database should use the `.default` identifier.
/// Create identifiers for your non-default databases by adding
/// a static extension to this struct:
///
///     extension DatabaseIdentifier {
///         /// My custom DB.
///         public static var myCustom: DatabaseIdentifier {
///             return DatabaseIdentifier("myCustom")
///         }
///     }
///
public struct DatabaseIdentifier<D: Database> {
    /// The unique id.
    public let uid: String

    /// Create a new database identifier.
    public init(_ uid: String, type: D.Type = D.self) {
        self.uid = uid
    }
}

extension DatabaseIdentifier: Equatable {
    public static func ==(lhs: DatabaseIdentifier, rhs: DatabaseIdentifier) -> Bool {
        return lhs.uid == rhs.uid
    }
}

extension DatabaseIdentifier: Hashable {
    public var hashValue: Int {
        return uid.hashValue
    }
}

// MARK: Default

extension DatabaseIdentifier: CustomStringConvertible {
    public var description: String {
        return uid
    }
}
