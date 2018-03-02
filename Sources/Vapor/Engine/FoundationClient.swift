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

    /// See `Client.respond(to:)`
    public func respond(to req: Request) throws -> Future<Response> {
        return req.http.makeFoundationRequest().flatMap(to: Response.self) { urlReq in
            let promise = Promise(Response.self)
            self.urlSession.dataTask(with: urlReq) { data, urlResponse, error in
                if let error = error {
                    promise.fail(error, onNextTick: self.container)
                    return
                }

                guard let httpResponse = urlResponse as? HTTPURLResponse else {
                    fatalError("URLResponse was not a HTTPURLResponse.")
                }

                let response = HTTPResponse.fromFoundationResponse(httpResponse, data: data)
                promise.complete(Response(http: response, using: self.container), onNextTick: self.container)
            }.resume()
            return promise.future
        }
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
    fileprivate func makeFoundationRequest() -> Future<URLRequest> {
        let http = self
        return http.body.makeData(max: 100_000).map(to: URLRequest.self) { body in
            let url = http.uri.makeFoundationURL()
            var request = URLRequest(url: url)
            request.httpMethod = http.method.string.uppercased()
            request.httpBody = body
            http.headers.forEach { key, val in
                request.addValue(val, forHTTPHeaderField: key.description)
            }
            return request
        }
    }
}

extension HTTPResponse {
    /// Creates an `HTTP.HTTPResponse` to `Foundation.URLResponse`
    fileprivate static func fromFoundationResponse(_ httpResponse: HTTPURLResponse, data: Data?) -> HTTPResponse {
        var res = HTTPResponse(status: .init(code: httpResponse.statusCode))
        for (key, value) in httpResponse.allHeaderFields {
            res.headers[.init("\(key)")] = "\(value)"
        }
        if let data = data {
            res.body = HTTPBody(data)
        }
        return res
    }
}

extension URI {
    /// Converts an `HTTP.URI` to a `Foundation.URL`
    fileprivate func makeFoundationURL() -> URL {
        var comps = URLComponents()
        comps.scheme = scheme
        comps.user = userInfo?.username
        comps.password = userInfo?.info
        comps.host = hostname
        comps.port = port.flatMap(Int.init)
        comps.path = path
        comps.query = query
        comps.fragment = fragment
        guard let url = comps.url else {
            fatalError()
        }
        return url
    }
}
