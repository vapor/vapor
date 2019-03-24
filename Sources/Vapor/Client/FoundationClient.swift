/// `Client` wrapper around `Foundation.URLSession`.
public final class FoundationClient {
    /// See `Client`.
    public var eventLoop: EventLoop

    /// The `URLSession` powering this client.
    private let urlSession: URLSession

    /// Creates a new `FoundationClient`.
    public init(_ urlSession: URLSession, on eventLoop: EventLoop) {
        self.urlSession = urlSession
        self.eventLoop = eventLoop
    }

    /// See `Client`.
    public func send(_ req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        let promise = self.eventLoop.makePromise(of: HTTPResponse.self)
        self.urlSession.dataTask(with: URLRequest(http: req)) { data, urlResponse, error in
            if let error = error {
                promise.fail(error)
                return
            }

            guard let httpURLResponse = urlResponse as? HTTPURLResponse else {
                let error = VaporError(
                    identifier: "httpURLResponse",
                    reason: "URLResponse was not a HTTPURLResponse."
                )
                promise.fail(error)
                return
            }

            let res = HTTPResponse(foundation: httpURLResponse, data: data)
            promise.succeed(res)
        }.resume()
        return promise.futureResult
    }
}

extension URLRequest {
    public init(http: HTTPRequest) {
        let body = http.body.data ?? Data()
        self.init(url: http.url)
        self.httpMethod = "\(http.method)"
        self.httpBody = body
        http.headers.forEach { key, val in
            self.addValue(val, forHTTPHeaderField: key.description)
        }
    }
}

extension HTTPResponse {
    public init(foundation: HTTPURLResponse, data: Data? = nil) {
        self.init(status: .init(statusCode: foundation.statusCode))
        if let data = data {
            self.body = HTTPBody(data: data)
        }
        for (key, value) in foundation.allHeaderFields {
            self.headers.replaceOrAdd(name: "\(key)", value: "\(value)")
        }
    }
}
