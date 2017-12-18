import MySQL

/// A single column's type
public struct ColumnType {
    /// The column's name
    public private(set) var name: String
    
    /// The textual length of the integer (decimal or character length)
    public private(set) var length: Int? = nil
    
    /// Any other attributes
    public private(set) var attributes = [String]()
    
    /// Serializes the spec
    var keywords: String {
        return attributes.joined(separator: " ")
    }
    
    var lengthName: String {
        guard let length = length else {
            return ""
        }
        
        return "(\(length))"
    }
    
    /// An internal method of creating the column
    init(name: String, length: Int? = nil, attributes: [String] = []) {
        self.name = name
        self.length = length
        self.attributes = attributes
    }
    
    /// A `varChar` column type, can be binary
    public static func varChar(length: Int, binary: Bool = false) -> ColumnType {
        var column = ColumnType(name: "VARCHAR", length: length)
        
        if binary {
            column.attributes.append("BINARY")
        }
        
        return column
    }
    
    /// A `varChar` column type, can be binary
    public static func tinyBlob(length: Int) -> ColumnType {
        return ColumnType(name: "TINYBLOB", length: length)
    }
    
    /// A `varChar` column type, can be binary
    public static func blob(length: Int) -> ColumnType {
        return ColumnType(name: "BLOB", length: length)
    }
    
    /// A single signed (TINY) byte with a maximum (decimal) length, if specified
    public static func int8(length: Int? = nil) -> ColumnType {
        return ColumnType(name: "TINYINT", length: length)
    }
    
    /// A single unsigned (TINY) byte with a maximum (decimal) length, if specified
    public static func uint8(length: Int? = nil) -> ColumnType {
        return ColumnType(name: "TINYINT", length: length, attributes: ["UNSIGNED"])
    }
    
    /// A single (signed SHORT) Int16 with a maximum (decimal) length, if specified
    public static func int16(length: Int? = nil) -> ColumnType {
        return ColumnType(name: "SMALLINT", length: length)
    }
    
    /// A single (unsigned SHORT) UInt16 with a maximum (decimal) length, if specified
    public static func uint16(length: Int? = nil) -> ColumnType {
        return ColumnType(name: "SMALLINT", length: length, attributes: ["UNSIGNED"])
    }
    
    /// A floating point (single precision) 32-bits number
    public static func float() -> ColumnType {
        return ColumnType(name: "FLOAT")
    }
    
    /// A floating point (double precision) 64-bits number
    public static func double() -> ColumnType {
        return ColumnType(name: "DOUBLE")
    }
    
    /// A MEDIUM integer (24-bits, stored as 32-bits)
    public static func int24(length: Int? = nil) -> ColumnType {
        return ColumnType(name: "MEDIUMINT", length: length)
    }
    
    /// An unsigned MEDIUM integer (24-bits, stored as 32-bits)
    public static func uint24(length: Int? = nil) -> ColumnType {
        return ColumnType(name: "MEDIUMINT", length: length, attributes: ["UNSIGNED"])
    }
    
    /// A (signed LONG) 32-bits integer
    public static func int32(length: Int? = nil) -> ColumnType {
        return ColumnType(name: "INT", length: length)
    }
    
    /// A (unsigned LONG) 32-bits integer
    public static func uint32(length: Int? = nil) -> ColumnType {
        return ColumnType(name: "INT", length: length, attributes: ["UNSIGNED"])
    }
    
    /// A (signed LONGLONG) 64-bits integer
    public static func int64(length: Int? = nil) -> ColumnType {
        return ColumnType(name: "BIGINT", length: length)
    }
    
    /// A (unsigned LONGLONG) 64-bits integer
    public static func uint64(length: Int? = nil) -> ColumnType {
        return ColumnType(name: "BIGINT", length: length, attributes: ["UNSIGNED"])
    }
    
    /// A DATE
    public static func date() -> ColumnType {
        return ColumnType(name: "DATE", length: nil)
    }
    
    /// A TEXT
    public static func text() -> ColumnType {
        return ColumnType(name: "TEXT", length: nil)
    }
    
    /// A DATETIME
    public static func datetime() -> ColumnType {
        return ColumnType(name: "DATETIME", length: nil)
    }
    
    /// A TIME
    public static func time() -> ColumnType {
        return ColumnType(name: "TIME", length: nil)
    }
}
