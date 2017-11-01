import Async

/// Outputs all notifications for a listening client's channels
public final class SubscriptionStream: Async.OutputStream {
    /// See `OutputStream.Notification`
    public typealias Notification = ChannelMessage
    
    /// See `OutputStream.NotificationCallback`
    public var outputStream: NotificationCallback?
    
    /// See `BaseStream.errorNotification`
    public let errorNotification = SingleNotification<Error>()
    
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
                    self.errorNotification.notify(of: RedisError(.unexpectedResult(data)))
                    return
            }
            
            // We're only accepting real notifications for now. No replies for completed subscribing and unsubscribing.
            guard array[0].string == "message" else {
                return
            }
            
            let message = ChannelMessage(channel: channel, message: array[2])
            
            self.outputStream?(message)
        }
    }
}
