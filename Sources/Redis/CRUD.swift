import Async

extension Client {
    @discardableResult
    public func set(_ value: RedisValue, forKey key: String) throws -> Future<Void> {
        return try self.runCommand(["SET", RedisValue(bulk: key), value]).map { result in
            if case .error(let error) = result {
                throw error
            }
        }
    }
    
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

