extension Entity {
    public func makeDirtyRow() throws -> Row {
        let current = try makeRow()
        guard let fetched = storage.fetchedRow else {
            return current
        }
        
        guard let object = current.object else {
            return current
        }
        
        var dirty = Row()
        
        for (key, value) in object {
            if fetched[key]?.wrapped != current[key]?.wrapped {
                dirty[key] = value
            }
        }
        
        return dirty
    }
}
