import Foundation
import Vapor
import NIOCore

extension ClientResponse: @unchecked Sendable  {
}

struct XCTHTTPClient: Client {
    
    let eventLoopGroup: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    let eventLoop: EventLoop
    var mockData: [ClientRequest: ClientResponse]
    
    init(eventLoop: EventLoop?, mockData: [ClientRequest: ClientResponse] = [:]) {
        self.eventLoop = eventLoop ?? eventLoopGroup.next()
        self.mockData = mockData
    }
    
    mutating func mock(request: ClientRequest, response: ClientResponse) {
        self.mockData[request] = response
    }
    
    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        
        if let matched = self.mockData.first(where: { $0.key == request }) {
            return self.eventLoop.future(matched.value)
        }
        
        return self.eventLoop.makeFailedFuture(Abort(.notFound))
    }
    
    internal func delegating(to eventLoop: EventLoop) -> Client {
        return Self.init(eventLoop: eventLoop)
    }
    
}

extension ClientRequest: Hashable {
    public static func == (lhs: ClientRequest, rhs: ClientRequest) -> Bool {
        return lhs.method == rhs.method
        && lhs.url.string == rhs.url.string
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.method.string)
        hasher.combine(self.url.string)
        hasher.combine(self.headers.description)
    }
}
