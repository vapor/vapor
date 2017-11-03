/// A message sent over pub/sub
public struct ChannelMessage {
    /// The channel this message was sent in
    var channel: String
    
    /// The message itself
    var message: RedisData
}

