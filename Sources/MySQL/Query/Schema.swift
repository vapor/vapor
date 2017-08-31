import Core

public final class Table {
    public struct Column {
        public private(set) var name: String
        public private(set) var type: ColumnType
        public private(set) var nullable: Bool
        public var autoIncrement = false
        public var primary = false
        public var unique = false
        
        var keywords: String {
            var keywords = [String]()
            
            if autoIncrement {
                keywords.append("AUTO_INCREMENT")
            }
            
            if unique {
                keywords.append("UNIQUE KEY")
            }
            
            if primary {
                keywords.append("PRIMARY KEY")
            }
            
            return type.keywords + keywords.joined(separator: " ")
        }
        
        public enum ColumnType {
            case int8(length: Int?), uint8(length: Int?)
            case int16(length: Int?), uint16(length: Int?)
            case int24(length: Int?), uint24(length: Int?)
            case int32(length: Int?), uint32(length: Int?)
            case int64(length: Int?), uint64(length: Int?)
            
            case varChar(length: Int, binary: Bool)
            
            var name: String {
                switch self {
                case .int8: return "TINYINT"
                case .uint8: return "TINYINT"
                case .int16: return "SMALLINT"
                case .uint16: return "SMALLINT"
                case .int24: return "MEDIUMINT"
                case .uint24: return "MEDIUMINT"
                case .int32: return "INT"
                case .uint32: return "INT"
                case .int64: return "BIGINT"
                case .uint64: return "BIGINT"
                case .varChar: return "VARCHAR"
                }
            }
            
            var length: Int? {
                switch self {
                case .int8(let length): return length
                case .uint8(let length): return length
                case .int16(let length): return length
                case .uint16(let length): return length
                case .int24(let length): return length
                case .uint24(let length): return length
                case .int32(let length): return length
                case .uint32(let length): return length
                case .int64(let length): return length
                case .uint64(let length): return length
                case .varChar(let length, _): return length
                }
            }
            
            var keywords: String {
                var words = [String]()
                
                switch self {
                case .uint8: words.append("UNSIGNED")
                case .uint16: words.append("UNSIGNED")
                case .uint32: words.append("UNSIGNED")
                case .uint64: words.append("UNSIGNED")
                default: break
                }
                
                return words.joined(separator: " ")
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

extension ConnectionPool {
    public func createTable(_ table: Table) throws -> Future<Void> {
        let temporary = table.temporary ? "TEMPORARY" : ""
        
        var query = "CREATE \(temporary) TABLE \(table.name) ("
        
        query += table.schema.map { field in
            let length: String
                
            if let lengthCount = field.type.length {
                length = "(\(lengthCount))"
            } else {
                length = ""
            }
            
            return "\(field.name) \(field.type.name)\(length) \(field.nullable ? "NULL" : "NOT NULL") \(field.keywords) "
        }.joined(separator: ", ")
        
        query += ")"
        
        return try self.allRows(in: query).map { _ in
            return ()
        }
    }
    
    public func dropTable(named name: String) throws -> Future<Void> {
        let query = "DROP TABLE \(name)"
        
        return try self.allRows(in: query).map { _ in
            return ()
        }
    }
    
    public func dropTables(named name: String...) throws -> Future<Void> {
        let query = "DROP TABLE \(name.joined(separator: ","))"
        
        return try self.allRows(in: query).map { _ in
            return ()
        }
    }
}
