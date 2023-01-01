import Foundation

public final class SpyClient: Client {
    private(set) var requestsUsed: [ClientRequest] = []
    
    private var stubResponse: ClientResponse = .init(status: .ok)
    
    public var eventLoop: EventLoop
    
    public init(
        eventLoop: EventLoop
    ) {
        self.eventLoop = eventLoop
    }
    
    // Conforming to the protocol: Client
    public func delegating(to eventLoop: EventLoop) -> Client {
        self.eventLoop = eventLoop
        
        return self
    }
    
    // Conforming to the protocol: Client
    public func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        self.requestsUsed.append(request)
        
        return self.eventLoop.future(self.stubResponse)
    }

    /// To be able to stub the response of a request made with the client.
    /// - Parameters:
    ///   - httpStatus: Provide HTTP status, you want the response to have
    ///   - responseData: Provide response data, you want the response to have
    public func stubResponse(httpStatus: HTTPStatus, responseData: (any Content)? = nil) throws {
        self.stubResponse = .init(status: httpStatus)
        
        if let responseData = responseData {
            try self.stubResponse.content.encode(responseData, as: .json)
        }
    }
}

