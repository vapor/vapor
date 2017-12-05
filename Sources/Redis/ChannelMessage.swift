/// A message sent over pub/sub
public struct ChannelMessage {
    /// The channel this message was sent in
    public var channel: String
    
    /// The message itself
    public var message: RedisData
}

