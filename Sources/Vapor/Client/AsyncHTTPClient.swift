import AsyncHTTPClient

public struct AsyncHTTPClient: Client {
    public let driver: HTTPClient
    public let eventLoop: EventLoop

    public func `for`(_ request: Request) -> Client {
        AsyncHTTPClient(driver: self.driver, eventLoop: request.eventLoop)
    }

    public func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        return self.driver.send(request, eventLoop: .delegate(on: self.eventLoop))
    }
}
