extension Config {
    /// Stores all resolved objects so they do not need
    /// to be resolved again.
    internal var resolved: [String: Any] {
        get { return storage["vapor:resolved"] as? [String: Any] ?? [:] }
        set { storage["vapor:resolved"] = newValue }
    }
    
    /// Resolves a single instance with the supplied information
    /// from the configurable items.
    public func customResolve<C>(
        unique: String,
        file: String,
        keyPath: [String],
        as type: C.Type,
        default d: Config.Lazy<C>
    ) throws -> C {
        try checkResolutionsCount()
        
        // check if this type has already been resolved
        if let resolved = self.resolved[unique] as? C {
            return resolved
        }
        
        // access the config at the suppplied file and 
        // path to see which item was chosen by the user.
        let path = [file] + keyPath
        guard let chosen = self[path]?.string else {
            return try d(self)
        }
        
        // construct the key
        let chosenKey = "\(unique)-\(chosen)"
        
        // access the configurable items and 
        // retreive the chosen one or fail.
        guard
            let configurable = self.configurable[chosenKey],
            let c = try configurable(self) as? C
        else {
            throw ConfigError.unavailable(
                value: chosen,
                key: keyPath,
                file: file,
                available: self.configurable.keys.available(for: unique),
                type: C.self
            )
        }

        // cache the resolved item so it does
        // not need to be resolved again
        self.resolved[unique] = c
        
        return c
    }
    
    /// Resolves an array of instances with the supplied information
    /// from the configurable items.
    public func customResolveArray<C>(
        unique: String,
        file: String,
        keyPath: [String],
        as type: C.Type,
        default d: (Config) throws -> [C]
    ) throws -> [C] {
        try checkResolutionsCount()
        
        // check if this type has already been resolved
        if let resolved = self.resolved[unique] as? [C] {
            return resolved
        }
        
        // access the config at the suppplied file and
        // path to see which items were chosen by the user.
        let path = [file] + keyPath
        #if swift(>=4.1)
        guard let chosen = self[path]?.array?.compactMap({ $0.string }) else {
            return try d(self)
        }
        #else
        guard let chosen = self[path]?.array?.flatMap({ $0.string }) else {
            return try d(self)
        }
        #endif
        
        // iterator over the array of chosen items
        // and find their configurables
        let configurables: [C] = try chosen.map { name in
            let chosenKey = "\(unique)-\(name)"
            
            // attempt to initialize the configurable
            // or throw an error
            guard
                let configurable = self.configurable[chosenKey],
                let c = try configurable(self) as? C
            else {
                throw ConfigError.unavailable(
                    value: name,
                    key: keyPath,
                    file: file,
                    available: self.configurable.keys.available(for: unique),
                    type: C.self
                )
            }
            
            return c
        }
        
        // cache the resolved items so they do
        // not need to be resolved again
        self.resolved[unique] = configurable
        
        return configurables
    }
}

// MARK: Resolutions

extension Config {
    /// Count the number of resolutions performed
    /// to detect cycles
    internal var resolutionsCount: Int {
        get { return storage["vapor:resolutions"] as? Int ?? 0 }
        set { storage["vapor:resolutions"] = newValue }
    }
    
    internal func checkResolutionsCount() throws {
        guard resolutionsCount < 256 else {
            throw ConfigError.maxResolve
        }
        
        resolutionsCount += 1
    }
}

// MARK: Utilities

extension Sequence where Iterator.Element == String {
    fileprivate func available(for unique: String) -> [String] {
        return array
            .filter { $0.hasPrefix(unique) }
            .map { $0.replacingOccurrences(of: "\(unique)-", with: "") }
    }
}
