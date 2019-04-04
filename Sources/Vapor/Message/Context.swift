public final class Context {
    public let channel: Channel
    
    public var eventLoop: EventLoop {
        return self.channel.eventLoop
    }
    
    public var parameters: Parameters
    
    public var userInfo: [AnyHashable: Any]
    
    public init(channel: Channel) {
        self.channel = channel
        self.parameters = .init()
        self.userInfo = [:]
    }
}
