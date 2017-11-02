import Async

extension RedisClient {
    /// Accepts an array of commands, to be sent in one request.
    public func pipeline(_ commands: () -> ([RedisData])) -> Future<[RedisData]> {
        if isSubscribed {
            return Future(error: RedisError(.cannotReuseSubscribedClients))
        }
        
        let commands = commands()
        dataSerializer.inputStream(commands)
        
        let promises = commands.map { _ in
            Promise<RedisData>()
        }
        
        dataParser.responseQueue.append(contentsOf: promises)
        
        return promises
            .map { $0.future }
            .flatten()
    }
}
