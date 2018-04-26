import Foundation

/// `Client` wrapper around `Foundation.URLSession`.
public final class FoundationClient: Client {
    /// See `Client.container`
    public var container: Container

    /// The `URLSession` powering this client.
    private let urlSession: URLSession

    /// Creates a new `FoundationClient`
    public init(_ urlSession: URLSession, on container: Container) {
        self.urlSession = urlSession
        self.container = container
    }

    /// Creates a `FoundationClient` with default settings.
    public static func `default`(on container: Container) -> FoundationClient {
        return .init(.init(configuration: .default), on: container)
    }

    /// See `Client`.
    public func send(_ req: Request) -> Future<Response> {
        let urlReq = req.http.makeFoundationRequest()
        let promise = req.eventLoop.newPromise(Response.self)
        self.urlSession.dataTask(with: urlReq) { data, urlResponse, error in
            if let error = error {
                promise.fail(error: error)
                return
            }

            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                fatalError("URLResponse was not a HTTPURLResponse.")
            }

            let response = HTTPResponse.fromFoundationResponse(httpResponse, data: data, on: self.container)
            promise.succeed(result: Response(http: response, using: self.container))
        }.resume()
        return promise.futureResult
    }
}

/// MARK: Service

extension FoundationClient: ServiceType {
    /// See `ServiceType.serviceSupports`
    public static var serviceSupports: [Any.Type] { return [Client.self] }

    /// See `ServiceType.makeService(for:)`
    public static func makeService(for worker: Container) throws -> FoundationClient {
        if let sub = worker as? SubContainer {
            /// if a request is creating a client, we should
            /// use the event loop as the container
            return .default(on: sub.superContainer)
        } else {
            return .default(on: worker)
        }
    }
}

/// MARK: Utility

extension HTTPRequest {
    /// Converts an `HTTP.HTTPRequest` to `Foundation.URLRequest`
    fileprivate func makeFoundationRequest() -> URLRequest {
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

extension HTTPResponse {
    /// Creates an `HTTP.HTTPResponse` to `Foundation.URLResponse`
    fileprivate static func fromFoundationResponse(_ httpResponse: HTTPURLResponse, data: Data?, on worker: Worker) -> HTTPResponse {
        var res = HTTPResponse(status: .init(statusCode: httpResponse.statusCode))
        for (key, value) in httpResponse.allHeaderFields {
            res.headers.replaceOrAdd(name: "\(key)", value: "\(value)")
        }
        if let data = data {
            res.body = HTTPBody(data: data)
        }
        return res
    }
}
