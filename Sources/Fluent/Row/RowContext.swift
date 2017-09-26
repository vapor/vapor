public final class RowContext: Context {
    public var database: Database?
    public init() {}
}

public let rowContext = RowContext()

extension Context {
    public var isRow: Bool {
        guard let _ = self as? RowContext else { return false }
        return true
    }

    public var database: Database? {
        guard let val = self as? RowContext else { return nil }
        return val.database
    }
}

