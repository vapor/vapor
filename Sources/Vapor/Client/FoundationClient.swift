import Foundation

/// `Client` wrapper around `Foundation.URLSession`.
public final class FoundationClient {
    /// See `Client`.
    public var eventLoop: EventLoop

    /// The `URLSession` powering this client.
    private let urlSession: URLSession

    /// Creates a new `FoundationClient`.
    public init(_ urlSession: URLSession, eventLoop: EventLoop) {
        self.urlSession = urlSession
        self.eventLoop = eventLoop
    }

    /// See `Client`.
    public func respond(to req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        let urlReq = req.convertToFoundationRequest()
        let promise = self.eventLoop.makePromise(of: HTTPResponse.self)
        self.urlSession.dataTask(with: urlReq) { data, urlResponse, error in
            if let error = error {
                promise.fail(error: error)
                return
            }

            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                let error = VaporError(identifier: "httpURLResponse", reason: "URLResponse was not a HTTPURLResponse.")
                promise.fail(error: error)
                return
            }

            let response = HTTPResponse.convertFromFoundationResponse(httpResponse, data: data)
            promise.succeed(result: response)
        }.resume()
        return promise.futureResult
    }
}

// MARK: Private

private extension HTTPRequest {
    /// Converts an `HTTP.HTTPRequest` to `Foundation.URLRequest`
    func convertToFoundationRequest() -> URLRequest {
        let http = self
        let body = http.body.data ?? Data()
        var request = URLRequest(url: http.url)
        request.httpMethod = "\(http.method)"
        request.httpBody = body
        http.headers.forEach { key, val in
            request.addValue(val, forHTTPHeaderField: key.description)
        }
        return request
    }
}

private extension HTTPResponse {
    /// Creates an `HTTP.HTTPResponse` to `Foundation.URLResponse`
    static func convertFromFoundationResponse(_ httpResponse: HTTPURLResponse, data: Data?) -> HTTPResponse {
        var res = HTTPResponse(status: .init(statusCode: httpResponse.statusCode))
        if let data = data {
            res.body = HTTPBody(data: data)
        }
        for (key, value) in httpResponse.allHeaderFields {
            res.headers.replaceOrAdd(name: "\(key)", value: "\(value)")
        }
        return res
    }
}
