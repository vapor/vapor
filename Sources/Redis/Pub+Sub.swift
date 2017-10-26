import Async

extension RedisClient {
    /// Subscribes to the given list of channels
    public func subscribe(to channels: Set<String>) -> SubscriptionStream {
        let channels = channels.map { name in
            return RedisData(bulk: name)
        }
        
        let command = RedisData.array(["SUBSCRIBE"] + channels)
        
        dataSerializer.inputStream(command)
        
        // Mark this client as being subscribed
        // The client cannot be used for other commands now
        self.subscribed = true
        
        return SubscriptionStream(reading: self.dataParser)
    }
    
    /// Publishes the message to a channels
    @discardableResult
    public func publish(_ message: RedisData, to channel: String) -> Future<Int> {
        return run(command: "PUBLISH", arguments: [.bulkString(channel), message]).map { reply in
            guard let receivers = reply.int else {
                throw RedisError(.unexpectedResult(reply))
            }
            
            return receivers
        }
    }
}

/// A message sent over pub/sub
public struct ChannelMessage {
    /// The channel this message was sent in
    var channel: String
    
    /// The message itself
    var message: RedisData
}

/// Outputs all notifications for a listening client's channels
public final class SubscriptionStream: Async.OutputStream {
    /// See `OutputStream.Output`
    public typealias Output = ChannelMessage
    
    /// See `OutputStream.OutputHandler`
    public var outputStream: OutputHandler?
    
    /// See `BaseStream.errorStream`
    public var errorStream: ErrorHandler?
    
    /// Drains a Redis Client's parser of it's results
    init(reading parser: DataParser) {
        parser.drain { data in
            guard
                let array = data.array,
                array.count == 3,
                let channel = array[1].string
            else {
                self.errorStream?(RedisError(.unexpectedResult(data)))
                return
            }
            
            guard array[0].string == "message" else {
                return
            }
            
            let message = ChannelMessage(channel: channel, message: array[2])
            
            self.outputStream?(message)
        }
    }
}
