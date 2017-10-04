/// An index is a copy of selected columns of data
/// from a table that can be searched very efficiently
public struct Index {
    /// The fields to include in the index
    public let fields: [String]
    
    public var name: String {
        let list = fields.joined(separator: "_")
        return "_fluent_idx_\(list)"
    }
    
    /// Creates a new index
    public init(fields: [String]) {
        self.fields = fields
    }
}

extension Database {
    // MARK: Create
    
    public func index<E: Model>(raw: String, for e: E.Type) throws {
        let query = Query<E>(self)
        query.action = .schema(.createIndex(.raw(raw, [])))
        try self.query(.some(query))
    }
    
    public func index<E: Model>(_ index: Index, for e: E.Type) throws {
        let query = Query<E>(self)
        query.action = .schema(.createIndex(.some(index)))
        try self.query(.some(query))
    }
    
    /// Adds an index to one field
    public func index<E: Model>(_ field: String, for e: E.Type) throws {
        let index = Index(fields: [field])
        try self.index(index, for: e)
    }
    
    /// Adds an index to multiple fields
    public func index<E: Model>(_ fields: [String], for e: E.Type) throws {
        let index = Index(fields: fields)
        try self.index(index, for: e)
    }
    
    // MARK: Delete
    
    public func deleteIndex<E: Model>(raw: String, for e: E.Type) throws {
        let query = Query<E>(self)
        query.action = .schema(.deleteIndex(.raw(raw, [])))
        try self.query(.some(query))
    }
    
    public func deleteIndex<E: Model>(_ index: Index, for e: E.Type) throws {
        let query = Query<E>(self)
        query.action = .schema(.deleteIndex(.some(index)))
        try self.query(.some(query))
    }
    
    /// Delete an index on a single column
    public func deleteIndex<E: Model>(_ field: String, for e: E.Type) throws {
        let index = Index(fields: [field])
        try deleteIndex(index, for: e)
    }
    
    /// Delete an index on multiple columns
    public func deleteIndex<E: Model>(_ fields: [String], for e: E.Type) throws {
        let index = Index(fields: fields)
        try deleteIndex(index, for: e)
    }
}
