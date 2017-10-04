import Async

extension Client {
    /// Stores the `value` at the key `key`
    ///
    /// - returns: A future that will be completed (or failed) when the key is stored or failed to be stored
    /// - throws: On network error
    @discardableResult
    public func set(_ value: RedisValue, forKey key: String) throws -> Future<Void> {
        return try self.runCommand(["SET", RedisValue(bulk: key), value]).map { result in
            if case .error(let error) = result {
                throw error
            }
        }
    }
    
    /// Removes the value at the key `key`
    ///
    /// - returns: A future that will be completed (or failed) when the key is removed or failed to be removed
    /// - throws: On network error
    @discardableResult
    public func delete(_ keys: String...) throws -> Future<Int> {
        let keys = keys.map { RedisValue(bulk: $0) }
        
        return try self.runCommand(.array(["DEL"] + keys)).map { result in
            if case .error(let error) = result {
                throw error
            }
            
            guard case .integer(let int) = result else {
                throw ClientError.unexpectedResult(result)
            }
            
            return int
        }
    }
    
    /// Fetches the value at the key `key`
    ///
    /// - returns: A future that will be completed (or failed) with the value associated with this `key`
    /// - throws: On network error
    @discardableResult
    public func getValue(forKey key: String) throws -> Future<RedisValue> {
        return try self.runCommand(["GET", RedisValue(bulk: key)]).map { result in
            if case .error(let error) = result {
                throw error
            }
            
            return result
        }
    }
}

