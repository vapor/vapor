import Async

extension RedisClient {
    /// Stores the `value` at the key `key`
    ///
    /// - returns: A future that will be completed (or failed) when the key is stored or failed to be stored
    @discardableResult
    public func set(_ value: RedisData, forKey key: String) -> Future<Void> {
        return self.run(command: "SET", arguments: [RedisData(bulk: key), value]).map { result in
            if case .error(let error) = result {
                throw error
            }
        }
    }
    
    /// Removes the value at the key `key`
    ///
    /// - returns: A future that will be completed (or failed) when the key is removed or failed to be removed
    @discardableResult
    public func delete(keys: [String]) -> Future<Int> {
        let keys = keys.map { RedisData(bulk: $0) }
        
        return self.run(command: "DEL", arguments: keys).map { result in
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
    @discardableResult
    public func getData(forKey key: String) -> Future<RedisData> {
        return self.run(command: "GET", arguments: [RedisData(bulk: key)]).map { result in
            if case .error(let error) = result {
                throw error
            }
            
            return result
        }
    }
}

