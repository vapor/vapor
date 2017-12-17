import Async

extension RedisClient {
    /// Subscribes to the given channel
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/redis/pub-sub/#subscribing)
    public func subscribe(to channel: String) -> SubscriptionStream {
        return self.subscribe(to: [channel])
    }
    
    /// Subscribes to the given list of channels
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/redis/pub-sub/#subscribing)
    public func subscribe(to channels: Set<String>) -> SubscriptionStream {
        let channels = channels.map { name in
            return RedisData(bulk: name)
        }
        
        _ = self.run(command: "SUBSCRIBE", arguments: channels)
        
        // Mark this client as being subscribed
        // The client cannot be used for other commands now
        self.isSubscribed = true

        return SubscriptionStream(reading: self.stream)
    }
    
    /// Publishes the message to a channels
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/redis/pub-sub/#publishing)
    @discardableResult
    public func publish(_ message: RedisData, to channel: String) -> Future<Int> {
        return run(command: "PUBLISH", arguments: [.bulkString(channel), message]).map(to: Int.self) { reply in
            guard let receivers = reply.int else {
                throw RedisError(.unexpectedResult(reply))
            }
            
            return receivers
        }
    }
}

