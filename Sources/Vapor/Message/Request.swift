public final class Request {
    public var http: HTTPRequest
    
    public let channel: Channel
    
    public var eventLoop: EventLoop {
        return self.channel.eventLoop
    }
    
    public var parameters: Parameters
    
    public var userInfo: [AnyHashable: Any]
    
    public init(http: HTTPRequest, channel: Channel) {
        self.http = http
        self.channel = channel
        self.parameters = .init()
        self.userInfo = [:]
    }
}
