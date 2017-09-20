import Core

extension ConnectionPool {
    /// Creates a table from the provided specification
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
            
            return "\(field.name) \(field.type.name)\(length) \(field.keywords) "
        }.joined(separator: ", ")
        
        query += ")"
        
        return try self.query(query)
    }
    
    /// Drops the table in the current database with the provided name
    public func dropTable(named name: String) throws -> Future<Void> {
        let query = "DROP TABLE \(name)"
        
        return try self.query(query)
    }
    
    /// Drops all tables from the current database with a name inside the provided list
    public func dropTables(named name: String...) throws -> Future<Void> {
        let query = "DROP TABLE \(name.joined(separator: ","))"
        
        return try self.query(query)
    }
}
