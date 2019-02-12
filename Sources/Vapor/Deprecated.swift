// nothing here yet...

@available(*, deprecated, renamed: "EventLoopFuture")
public typealias Future<T> = EventLoopFuture<T>

@available(*, deprecated, renamed: "HTTPResponse")
public typealias Response = HTTPResponse

@available(*, deprecated, renamed: "HTTPContentConfig")
public typealias ContentCoders = HTTPContentConfig

extension HTTPRequest {
    @available(*, deprecated, message: "Use HTTP members directly on HTTPRequest.")
    public var http: HTTPRequest {
        get { return self }
    }
}

extension HTTPResponse {
    @available(*, deprecated, message: "Use HTTP members directly on HTTPResponse.")
    public var http: HTTPResponse {
        get { return self }
    }
}
