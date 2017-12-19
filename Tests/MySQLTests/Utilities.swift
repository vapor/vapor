import Async
import MySQL

/// A table specification a helper, used for creating tables
///
/// - TODO: Review the API before tagging
public final class Table {
    /// A column specification, a single column inside a table
    public struct Column {
        /// The column's API
        public private(set) var name: String
        
        /// The column's type
        public private(set) var type: ColumnType
        
        /// If `true`, this field can be `NULL`
        public var nullable = false
        
        /// If `true`, this field is automatically incremented by 1
        public var autoIncrement = false
        
        /// If `true`, this field is `PRIMARY KEY` and thus also unique
        public var primary = false
        
        /// If `true`, this field is guaranteed to be unique
        public var unique = false
        
        /// Creates a new column based on the specification provided
        public init(named name: String, type: ColumnType, autoIncrement: Bool = false, primary: Bool = false, unique: Bool = false) {
            self.name = name
            self.type = type
            self.autoIncrement = autoIncrement
            self.primary = primary
            self.unique = unique
        }
        
        /// Helps construct a creation query
        public var keywords: String {
            var keywords = [type.keywords]
            
            if self.nullable {
                keywords.append("NULL")
            } else {
                keywords.append("NOT NULL")
            }
            
            if primary {
                keywords.append("PRIMARY KEY")
            } else {
                if unique {
                    keywords.append("UNIQUE")
                }
            }
            
            if autoIncrement {
                keywords.append("AUTO_INCREMENT")
            }
            
            return keywords.joined(separator: " ")
        }
        
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
            
            /// An internal method of creating the column
            init(name: String, length: Int? = nil, attributes: [String] = []) {
                self.name = name
                self.length = length
                self.attributes = attributes
            }
            
            /// A `varChar` column type, can be binary
            public static func varChar(length: Int, binary: Bool) -> ColumnType {
                var column = ColumnType(name: "VARCHAR", length: length)
                
                if binary {
                    column.attributes.append("BINARY")
                }
                
                return column
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
        }
    }
    
    /// The Table's name
    public private(set) var name: String
    
    public private(set) var temporary: Bool
    
    /// The table's schema
    public var schema = [Column]()
    
    /// Creates a new (empty) table
    ///
    /// It's schema can be manipulated
    public init(named name: String, temporary: Bool = false) {
        self.name = name
        self.temporary = temporary
    }
}


extension MySQLConnection {
    /// Creates a table from the provided specification
    public func createTable(_ table: Table) -> Future<Void> {
        let temporary = table.temporary ? "TEMPORARY" : ""
        
        var query = "CREATE \(temporary) TABLE \(table.name) ("
        
        query += table.schema.map { field in
            let length: String
            
            if let lengthCount = field.type.length {
                length = "(\(lengthCount))"
            } else {
                length = ""
            }
            
            return "\(field.name) \(field.type.name)\(length) \(field.keywords) "
        }.joined(separator: ", ")
        
        query += ")"
        
        return self.administrativeQuery(query)
    }
    
    /// Drops the table in the current database with the provided name
    public func dropTable(named name: String) -> Future<Void> {
        let query = "DROP TABLE \(name)"
        
        return self.administrativeQuery(query)
    }
    
    /// Drops all tables from the current database with a name inside the provided list
    public func dropTables(named name: String...) -> Future<Void> {
        let query = "DROP TABLE \(name.joined(separator: ","))"
        
        return self.administrativeQuery(query)
    }
}
