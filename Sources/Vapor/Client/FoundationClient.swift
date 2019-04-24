extension HTTPHeaders {
    public init(foundation headers: [AnyHashable: Any]) {
        self.init()
        for (key, val) in headers {
            self.add(name: key as! String, value: val as! String)
        }
    }
}

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
    public func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        let promise = self.eventLoop.makePromise(of: ClientResponse.self)
        self.urlSession.dataTask(with: URLRequest(client: request)) { data, urlResponse, error in
            if let error = error {
                promise.fail(error)
                return
            }

            guard let httpURLResponse = urlResponse as? HTTPURLResponse else {
                fatalError("URLResponse was not a HTTPURLResponse")
            }

            let response = ClientResponse(foundation: httpURLResponse, data: data)
            promise.succeed(response)
        }.resume()
        return promise.futureResult
    }
}

private extension URLRequest {
    init(client request: ClientRequest) {
        self.init(url: request.url)
        self.httpMethod = request.method.string
        if var body = request.body {
            self.httpBody = body.readData(length: body.readableBytes)
        }
        request.headers.forEach { key, val in
            self.addValue(val, forHTTPHeaderField: key.description)
        }
    }
}

private extension ClientResponse {
    init(foundation: HTTPURLResponse, data: Data? = nil) {
        self.init(status: .init(statusCode: foundation.statusCode))
        if let data = data, !data.isEmpty {
            var buffer = ByteBufferAllocator().buffer(capacity: data.count)
            buffer.writeBytes(data)
            self.body = buffer
        }
        for (key, value) in foundation.allHeaderFields {
            self.headers.replaceOrAdd(name: "\(key)", value: "\(value)")
        }
    }
}
