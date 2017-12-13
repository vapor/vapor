import Bits
import CSQLite
import Foundation

extension SQLiteQuery {
    /// Binds SQLite data to the query.
    @discardableResult
    public func bind(_ sqliteData: SQLiteData) -> Self {
        binds.append(sqliteData)
        return self
    }

    /// Bind a Double to the current bind position.
    @discardableResult
    public func bind(_ value: Double) -> Self {
        bind(.float(value))
        return self
    }

    /// Bind an Int to the current bind position.
    @discardableResult
    public func bind(_ value: Int) -> Self {
        bind(.integer(value))
        return self
    }

    /// Bind a String to the current bind position.
    @discardableResult
    public func bind(_ value: String) -> Self {
        bind(.text(value))
        return self
    }

    /// Bind Bytes to the current bind position.
    @discardableResult
    public func bind(_ value: Data) -> Self {
        bind(.blob(value))
        return self
    }

    /// Bind a Bool to the current bind position.
    @discardableResult
    public func bind(_ value: Bool) -> Self {
        return bind(value ? 1 : 0)
    }

    /// Binds null to the current bind position
    @discardableResult
    public func bindNull() -> Self {
        bind(.null)
        return self
    }

}
