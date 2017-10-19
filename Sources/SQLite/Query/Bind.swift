import Bits
import CSQLite
import Foundation

extension SQLiteQuery {
    /// Binds SQLite data to the query.
    @discardableResult
    public func bind(_ sqliteData: SQLiteData) throws -> Self {
        switch sqliteData {
        case .blob(let data):
            return try bind(data)
        case .float(let float):
            return try bind(float)
        case .integer(let int):
            return try bind(int)
        case .text(let string):
            return try bind(string)
        case .null:
            return try bindNull()
        }
    }

    /// Bind a Double to the current bind position.
    @discardableResult
    public func bind(_ value: Double) throws -> Self {
        let ret = sqlite3_bind_double(raw, nextBindPosition, value)
        guard ret == SQLITE_OK else {
            throw SQLiteError(statusCode: ret, connection: connection)
        }
        return self
    }

    /// Bind an Int to the current bind position.
    @discardableResult
    public func bind(_ value: Int) throws -> Self {
        let ret = sqlite3_bind_int64(raw, nextBindPosition, Int64(value))
        guard ret == SQLITE_OK else {
            throw SQLiteError(statusCode: ret, connection: connection)
        }
        return self
    }

    /// Bind a String to the current bind position.
    @discardableResult
    public func bind(_ value: String) throws -> Self {
        let strlen = Int32(value.utf8.count)
        let ret = sqlite3_bind_text(raw, nextBindPosition, value, strlen, SQLITE_TRANSIENT)
        guard ret == SQLITE_OK else {
            throw SQLiteError(statusCode: ret, connection: connection)
        }
        return self
    }

    /// Bind Bytes to the current bind position.
    @discardableResult
    public func bind(_ value: Data) throws -> Self {
        let count = Int32(value.count)
        let pointer: UnsafePointer<Byte> = value.withUnsafeBytes { $0 }
        let ret = sqlite3_bind_blob(raw, nextBindPosition, UnsafeRawPointer(pointer), count, SQLITE_TRANSIENT)
        guard ret == SQLITE_OK else {
            throw SQLiteError(statusCode: ret, connection: connection)
        }
        return self
    }

    /// Bind a Bool to the current bind position.
    @discardableResult
    public func bind(_ value: Bool) throws -> Self {
        return try bind(value ? 1 : 0)
    }

    /// Binds null to the current bind position
    @discardableResult
    public func bindNull() throws -> Self {
        let ret = sqlite3_bind_null(raw, nextBindPosition)
        if ret != SQLITE_OK {
            throw SQLiteError(statusCode: ret, connection: connection)
        }
        return self
    }

}
