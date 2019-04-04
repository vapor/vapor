/// `Client` wrapper around `Foundation.URLSession`.
public final class FoundationClient: Client {
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
    public func send(method: HTTPMethod, url: URL, headers: HTTPHeaders, body: Data) -> EventLoopFuture<Response> {
        let promise = self.eventLoop.makePromise(of: Response.self)
        self.urlSession.dataTask(with: URLRequest(method: method, url: url, headers: headers, body: body)) { data, urlResponse, error in
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

            let res = Response(foundation: httpURLResponse, data: data)
            promise.succeed(res)
        }.resume()
        return promise.futureResult
    }
}

extension URLRequest {
    public init(method: HTTPMethod, url: URL, headers: HTTPHeaders, body: Data) {
        self.init(url: url)
        self.httpMethod = method.string
        self.httpBody = body
        headers.forEach { key, val in
            self.addValue(val, forHTTPHeaderField: key.description)
        }
    }
}

extension Response {
    public convenience init(foundation: HTTPURLResponse, data: Data? = nil) {
        self.init(status: .init(statusCode: foundation.statusCode))
        if let data = data {
            self.body = .init(data: data)
        }
        for (key, value) in foundation.allHeaderFields {
            self.headers.replaceOrAdd(name: "\(key)", value: "\(value)")
        }
    }
}
