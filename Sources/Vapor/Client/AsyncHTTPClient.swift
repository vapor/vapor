import AsyncHTTPClient

public struct AsyncHTTPClient: Client {
    let http: HTTPClient
    public let eventLoop: EventLoop

    public func `for`(_ request: Request) -> Client {
        AsyncHTTPClient(http: self.http, eventLoop: request.eventLoop)
    }

    public func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        return self.http.send(request, eventLoop: .delegate(on: self.eventLoop))
    }
}
