import AsyncHTTPClient

public struct AsyncHTTPClient: Client {
    let http: HTTPClient
    public let eventLoop: EventLoop

    public func `for`(_ request: Request) -> Client {
        AsyncHTTPClient(http: self.http, eventLoop: request.eventLoop)
    }

    public func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        return self.http.send(request, eventLoop: HTTPClient.EventLoopPreference.delegate(on: self.eventLoop))
    }
}

extension HTTPClient {
    internal func send(
        _ client: ClientRequest,
        eventLoop: HTTPClient.EventLoopPreference
    ) -> EventLoopFuture<ClientResponse> {
        do {
            let request = try HTTPClient.Request(
                url: URL(string: client.url.string)!,
                method: client.method,
                headers: client.headers,
                body: client.body.map { .byteBuffer($0) }
            )
            return self.execute(request: request, eventLoop: eventLoop).map { response in
                let client = ClientResponse(
                    status: response.status,
                    headers: response.headers,
                    body: response.body
                )
                return client
            }
        } catch {
            return self.eventLoopGroup.next().makeFailedFuture(error)
        }
    }
}

extension ClientConfiguration {
    func asHTTPClientConfiguration() -> HTTPClient.Configuration {
        return .init(
            tlsConfiguration: self.tlsConfiguration,
            redirectConfiguration: self.redirectConfiguration.asHTTPClientRedirectConfiguration(),
            timeout: self.timeout.asHTTPClientConfigurationTimeout(),
            proxy: self.proxy?.asHTTPClientConfigurationProxy(),
            ignoreUncleanSSLShutdown: self.ignoreUncleanSSLShutdown,
            decompression: self.decompression.asHTTPClientDecompression()
        )
    }
}

extension ClientConfiguration.Decompression {
    func asHTTPClientDecompression() -> HTTPClient.Decompression {
        switch self {
        case .disabled:
            return .disabled
        case .enabled(let limit):
            return .enabled(limit: limit)
        }
    }
}

extension ClientConfiguration.Authorization {
    func asHTTPClientAuthorization() -> HTTPClient.Authorization {
        switch scheme {
        case .Basic(let credentials):
            return HTTPClient.Authorization.basic(credentials: credentials)
        case .Bearer(let tokens):
            return HTTPClient.Authorization.bearer(tokens: tokens)
        }
    }
}

extension ClientConfiguration.RedirectConfiguration {
    func asHTTPClientRedirectConfiguration() -> HTTPClient.Configuration.RedirectConfiguration {
        switch configuration {
        case .disallow:
            return HTTPClient.Configuration.RedirectConfiguration.disallow
        case .follow(let max, let allowCycles):
            return HTTPClient.Configuration.RedirectConfiguration.follow(max: max, allowCycles: allowCycles)
        }
    }
}

extension ClientConfiguration.Proxy {
    func asHTTPClientConfigurationProxy() -> HTTPClient.Configuration.Proxy {
        return HTTPClient.Configuration.Proxy.server(host: self.host, port: self.port, authorization: self.authorization?.asHTTPClientAuthorization())
    }
}

extension ClientConfiguration.Timeout {
    func asHTTPClientConfigurationTimeout() -> HTTPClient.Configuration.Timeout {
        return HTTPClient.Configuration.Timeout(connect: self.connect, read: self.read)
    }
}
