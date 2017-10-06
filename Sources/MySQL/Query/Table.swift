public final class Table {
    public struct Column {
        public private(set) var name: String
        public private(set) var type: ColumnType
        public var nullable = false
        public var autoIncrement = false
        public var primary = false
        public var unique = false
        
        public init(named name: String, type: ColumnType, autoIncrement: Bool = false, primary: Bool = false, unique: Bool = false) {
            self.name = name
            self.type = type
            self.autoIncrement = autoIncrement
            self.primary = primary
            self.unique = unique
        }
        
        var keywords: String {
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
        
        public struct ColumnType {
            init(name: String, length: Int? = nil, attributes: [String] = []) {
                self.name = name
                self.length = length
                self.attributes = attributes
            }
            
            public static func varChar(length: Int, binary: Bool) -> ColumnType {
                var column = ColumnType(name: "VARCHAR", length: length)
                
                if binary {
                    column.attributes.append("BINARY")
                }
                
                return column
            }
            
            public static func int8(length: Int? = nil) -> ColumnType {
                return ColumnType(name: "TINYINT", length: length)
            }
            
            public static func uint8(length: Int? = nil) -> ColumnType {
                return ColumnType(name: "TINYINT", length: length, attributes: ["UNSIGNED"])
            }
            
            public static func int16(length: Int? = nil) -> ColumnType {
                return ColumnType(name: "SMALLINT", length: length)
            }
            
            public static func float() -> ColumnType {
                return ColumnType(name: "FLOAT")
            }
            
            public static func double() -> ColumnType {
                return ColumnType(name: "DOUBLE")
            }
            
            public static func uint16(length: Int? = nil) -> ColumnType {
                return ColumnType(name: "SMALLINT", length: length, attributes: ["UNSIGNED"])
            }
            
            public static func int24(length: Int? = nil) -> ColumnType {
                return ColumnType(name: "MEDIUMINT", length: length)
            }
            
            public static func uint24(length: Int? = nil) -> ColumnType {
                return ColumnType(name: "MEDIUMINT", length: length, attributes: ["UNSIGNED"])
            }
            
            public static func int32(length: Int? = nil) -> ColumnType {
                return ColumnType(name: "INT", length: length)
            }
            
            public static func uint32(length: Int? = nil) -> ColumnType {
                return ColumnType(name: "INT", length: length, attributes: ["UNSIGNED"])
            }
            
            public static func int64(length: Int? = nil) -> ColumnType {
                return ColumnType(name: "BIGINT", length: length)
            }
            
            public static func uint64(length: Int? = nil) -> ColumnType {
                return ColumnType(name: "BIGINT", length: length, attributes: ["UNSIGNED"])
            }
            
            var name: String
            
            var length: Int? = nil
            var attributes = [String]()
            
            var keywords: String {
                return attributes.joined(separator: " ")
            }
        }
    }
    
    public private(set) var name: String
    public private(set) var temporary: Bool
    public var schema = [Column]()
    
    public init(named name: String, temporary: Bool = false) {
        self.name = name
        self.temporary = temporary
    }
}
