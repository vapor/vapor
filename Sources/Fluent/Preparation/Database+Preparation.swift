extension Database {
    // MARK: Prepare
    
    public func prepare(_ preparations: [Preparation.Type]) throws {
        try prepareMetadata()
        let batch = try latestBatch() + 1
        for preparation in preparations {
            try prepare(preparation, batch: batch)
        }
    }
    
    // MARK: Revert
    
    public func revertAll(_ preparations: [Preparation.Type]) throws {
        try prepareMetadata()
        let preparations = preparations.reversed()
        for preparation in preparations {
            if let migration = try migration(for: preparation) {
                try preparation.revert(self)
                try migration.delete()
            }
        }
    }
    
    public func previewRevertBatch(_ preparations: [Preparation.Type]) throws -> (batch: Int, revert: [Preparation.Type]) {
        try prepareMetadata()
        let batch = try latestBatch()
        var toBeReverted: [Preparation.Type] = []
        let preparations = preparations.reversed()
        for preparation in preparations {
            if let migration = try migration(for: preparation), migration.batch == batch {
                toBeReverted.append(preparation)
            }
        }
        
        return (batch, toBeReverted)
    }
    
    public func revertBatch(_ preparations: [Preparation.Type]) throws {
        try prepareMetadata()
        let batch = try latestBatch()
        let preparations = preparations.reversed()
        for preparation in preparations {
            if let migration = try migration(for: preparation), migration.batch == batch {
                try preparation.revert(self)
                try migration.delete()
            }
        }
    }
    
    // MARK: Metadata
    
    public func revertMetadata() throws {
        try Migration.revert(self)
    }
    
    public func prepareMetadata() throws {
        Migration.database = self
        do {
            _ = try Migration.count()
        } catch {
            // could not fetch migrations
            // try to create `.fluent` table
            try Migration.prepare(self)
        }
    }
    
    // MARK: Private
    
    private func latestBatch() throws -> Int {
        return try Migration
            .makeQuery()
            .sort("batch", .descending)
            .first()?
            .batch ?? 0
    }
    
    private func migration(for preparation: Preparation.Type) throws -> Migration? {
        return try Migration
            .makeQuery()
            .filter("name", preparation.name)
            .first()
    }
    
    private func hasPrepared(_ preparation: Preparation.Type) throws -> Bool {
        // check to see if this preparation has already run
        if let _ = try migration(for: preparation) {
            return true
        }
        
        return false
    }
    
    private func prepare(_ preparation: Preparation.Type, batch: Int) throws {
        Migration.database = self
        
        if try hasPrepared(preparation) {
            // already prepared, set entity db
            if let model = preparation as? Model.Type {
                model.database = self
            }
            return
        }
        
        try preparation.prepare(self)
        
        if let model = preparation as? Model.Type {
            // preparation successful, set entity db
            model.database = self
        }
        
        // record that this preparation has run
        let migration = Migration(
            name: preparation.name,
            batch: batch
        )
        try migration.save()
    }
}

extension Preparation {
    fileprivate static var name: String {
        let _type = "\(type(of: self))"
        return _type.components(separatedBy: ".Type").first ?? _type
    }
}
