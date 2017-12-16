/// Available SQLite storage methods.
public enum SQLiteStorage {
    case memory
    case file(path: String)

    internal var path: String {
        switch self {
        case .memory:
            return ":memory:"
        case .file(let path):
            return path
        }
    }
}
