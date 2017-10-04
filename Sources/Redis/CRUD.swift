import Async

extension Client {
    public func set(_ value: RedisValue, forKey key: String) throws -> Future<Void> {
        return try self.runCommand(["SET", RedisValue(bulk: key), value]).map { result in
            if case .error(let error) = result {
                throw error
            }
        }
    }
    
    public func getValue(forKey key: String) throws -> Future<RedisValue> {
        return try self.runCommand(["GET", RedisValue(bulk: key)]).map { result in
            if case .error(let error) = result {
                throw error
            }
            
            return result
        }
    }
}

