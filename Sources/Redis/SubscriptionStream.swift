import Async

/// Outputs all notifications for a listening client's channels
///
/// [Learn More →](http://localhost:8000/redis/pub-sub/#subscribing)
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
            // Extracts the notification from this message
            //
            // - The type of notification
            // - The channel on which the notification is emitted
            // - The notification's payload
            guard
                let array = data.array,
                array.count == 3,
                let channel = array[1].string
                else {
                    self.errorStream?(RedisError(.unexpectedResult(data)))
                    return
            }
            
            // We're only accepting real notifications for now. No replies for completed subscribing and unsubscribing.
            guard array[0].string == "message" else {
                return
            }
            
            let message = ChannelMessage(channel: channel, message: array[2])
            
            self.output(message)
        }
    }
}
