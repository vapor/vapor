import Async

/// Outputs all notifications for a listening client's channels
///
/// [Learn More →](https://docs.vapor.codes/3.0/redis/pub-sub/#subscribing)
public final class SubscriptionStream: Async.Stream, ConnectionContext {
    /// See InputStream.Input
    public typealias Input = RedisData
    
    /// See OutputStream.Output
    public typealias Output = ChannelMessage
    
    /// The downstream, listening for messages
    private var downstream: AnyInputStream<Output>?
    
    /// The upstream output stream supplying redis data
    private var upstream: ConnectionContext?
    
    /// Drains a Redis Client's parser of it's results
    init(reading parser: RedisDataParser) {
        self.upstream = parser
        parser.output(to: self)
    }
    
    public func output<S>(to inputStream: S) where S : InputStream, SubscriptionStream.Output == S.Input {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }
    
    public func connection(_ event: ConnectionEvent) {
        switch event {
        case .request(let count):
            /// downstream has requested output
            upstream?.request(count: count)
        case .cancel:
            /// FIXME: handle
            upstream?.cancel()
        }
    }

    public func input(_ event: InputEvent<RedisData>) {
        switch event {
        case .close: downstream?.close()
        case .error(let error):
            downstream?.error(error)
        case .connect(let upstream):
            self.upstream = upstream
            downstream?.connect(to: upstream)
        case .next(let input):
            process(input)
        }
    }
    
    func process(_ data: RedisData) {
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
            self.downstream?.error(RedisError(.unexpectedResult(data)))
            self.request(count: 1)
            self.close()
            return
        }
        
        // We're only accepting real notifications for now. No replies for completed subscribing and unsubscribing.
        guard array[0].string == "message" else {
            // Request more data
            self.request(count: 1)
            return
        }
        
        let message = ChannelMessage(channel: channel, message: array[2])
        
        self.downstream?.next(message)
    }
}

