extension Database {
    /// Creates the schema of the database
    /// for the given entity.
    public func create<E: Model>(_ e: E.Type, closure: (Creator) throws -> ()) throws {
        if e.database == nil { e.database = self }

        let creator = Creator(E.self)
        try closure(creator)

        // add timestamps
        if let T = E.self as? Timestampable.Type {
            creator.date(T.createdAtKey)
            creator.date(T.updatedAtKey)
        }

        // add soft delete
        if let S = E.self as? SoftDeletable.Type {
            creator.date(S.deletedAtKey, optional: true)
        }

        let query = Query<E>(self)
        query.action = .schema(.create(
            fields: creator.fields,
            foreignKeys: creator.foreignKeys
        ))
        try self.query(.some(query))
    }

    /// Modifies the schema of the database
    /// for the given entity.
    public func modify<E: Model>(_ e: E.Type, closure: (Modifier) throws -> ()) throws {
        if e.database == nil { e.database = self }

        let modifier = Modifier(E.self)
        try closure(modifier)

        let query = Query<E>(self)
        query.action = .schema(.modify(
            fields: modifier.fields,
            foreignKeys: modifier.foreignKeys,
            deleteFields: modifier.deleteFields,
            deleteForeignKeys: modifier.deleteForeignKeys
        ))
        try self.query(.some(query))
    }

    /// Deletes the schema of the database
    /// for the given entity.
    public func delete<E: Model>(_ e: E.Type) throws {
        if e.database == nil { e.database = self }

        let query = Query<E>(self)
        query.action = .schema(.delete)
        try self.query(.some(query))
    }
}
