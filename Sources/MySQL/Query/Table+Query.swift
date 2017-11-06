import Async
import Core

// TODO: Is this useful?
extension ConnectionPool {
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
        
        return self.query(query)
    }
    
    /// Drops the table in the current database with the provided name
    public func dropTable(named name: String) -> Future<Void> {
        let query = "DROP TABLE \(name)"
        
        return self.query(query)
    }
    
    /// Drops all tables from the current database with a name inside the provided list
    public func dropTables(named name: String...) -> Future<Void> {
        let query = "DROP TABLE \(name.joined(separator: ","))"
        
        return self.query(query)
    }
}
