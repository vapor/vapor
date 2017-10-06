import Bits
import CSQLite
import Foundation

/// A single SQLite field. There are one or more of these per Row.
/// Each field references a unique column for that result set.
public struct SQLiteField {
    /// The field's data
    public var data: SQLiteData

    /// Create a new SQLite field from the data.
    public init(data: SQLiteData) {
        self.data = data
    }

    /// Create a field from statement pointer, column, and offset.
    init(statement: SQLiteQuery, offset: Int32) throws {
        let type = try SQLiteFieldType(statement: statement, offset: offset)
        switch type {
        case .integer:
            let val = sqlite3_column_int64(statement.raw, offset)
            let integer = Int(val)
            data = .integer(integer)
        case .float:
            let val = sqlite3_column_double(statement.raw, offset)
            let double = Double(val)
            data = .float(double)
        case .text:
            guard let val = sqlite3_column_text(statement.raw, offset) else {
                throw SQLiteError(problem: .error, reason: "Unexpected nil column text.")
            }
            let string = String(cString: val)
            data = .text(string)
        case .blob:
            let blobPointer = sqlite3_column_blob(statement.raw, offset)
            let length = Int(sqlite3_column_bytes(statement.raw, offset))

            let buffer = UnsafeBufferPointer(
                start: blobPointer?.assumingMemoryBound(to: Byte.self),
                count: length
            )
            data = .blob(Foundation.Data(buffer: buffer))
        case .null:
            data = .null
        }
    }
}

extension SQLiteField: CustomStringConvertible {
    /// Description of field
    public var description: String {
        return data.description
    }
}
