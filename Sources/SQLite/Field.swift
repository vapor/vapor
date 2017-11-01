import Bits
import CSQLite
import Foundation

/// A single SQLite field. There are one or more of these per Row.
/// Each field references a unique column for that result set.
public struct Field {
    /// A pointer to the column for this field
    public var column: Column

    /// The field's data
    public var data: Data

    /// Create a field from statement pointer, column, and offset.
    init(statement: Query, column: Column, offset: Int32) throws {
        let type = try FieldType(statement: statement, offset: offset)
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

        self.column = column
    }
}
