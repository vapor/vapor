/// The lowest level executor. All
/// calls to higher level executors
/// eventually end up here.
public protocol Connection: Executor {
    /// Indicates whether the connection has
    /// closed permanently and should be discarded.
    var isClosed: Bool { get }
}

public enum ConnectionType {
    case read
    case readWrite
}

extension Query {
    public var connectionType: ConnectionType {
        switch action {
        case .aggregate, .fetch:
            return .read
        case .create, .modify, .delete, .schema:
            return .readWrite
        }
    }
}
