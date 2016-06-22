public enum HTTPClientError: ErrorProtocol {
    case missingHost
}

public final class HTTPClient<ClientStreamType: ClientStream>: Client {
    public let client: ClientStreamType
    public let base: URI
    public private(set) var stream: Stream

    public init(_ base: URI) throws {
        self.base = base

        guard let host = base.host else { throw HTTPClientError.missingHost }
        let port = base.port ?? base.schemePort ?? 80
        let securityLayer = base.scheme?.securityLayer ?? .tls // Default to secure -- opt out
        let client = try ClientStreamType(host: host, port: port, securityLayer: securityLayer)
        let stream = try client.connect()

        self.client = client
        self.stream = stream
    }

    deinit {
        if !stream.closed {
            _ = try? stream.close()
        }
    }
    
    public func respond(to request: Request) throws -> Response {
        let uri = base.combine(with: request.uri)
        let request = request.updated(with: uri)
        
        if stream.closed {
            stream = try client.connect()
        }
        let buffer = StreamBuffer(stream)

        request.headers["Host"] = uri.host

        let serializer = HTTPSerializer<Request>(stream: buffer)
        try serializer.serialize(request)

        let parser = HTTPParser<Response>(stream: buffer)
        let response = try parser.parse()

        try buffer.flush()
        return response
    }
}

extension Request {
    func updated(with uri: URI) -> Request {
        return Request(method: method, uri: uri, version: version, headers: headers, body: body)
    }
}

extension URI {
    func combine(with uri: URI) -> URI {
        let scheme = choose(self.scheme, uri.scheme)
        let host = choose(self.host, uri.host)
        let userInfo = self.userInfo ?? uri.userInfo
        let port = self.port ?? uri.schemePort ?? uri.port ?? uri.schemePort ?? 80
        let currentPath = self.path ?? ""
        var newPath = uri.path ?? ""
        if newPath.hasPrefix("/") {
            newPath = String(newPath.characters.dropFirst())
        }
        let path = currentPath.finish("/") + newPath
        let query = self.appended(query: uri.query)
        let fragment = self.appended(fragment: uri.fragment)
        return URI(scheme: scheme, userInfo: userInfo, host: host, port: port, path: path, query: query, fragment: fragment)
    }

    private func choose(_ lhs: String?, _ rhs: String?) -> String? {
        if let lhs = lhs where !lhs.isEmpty {
            return lhs
        } else {
            return rhs
        }
    }
}

extension URI {
    public func appended(fragment appendFragment: String?) -> String? {
        guard let appendFragment = appendFragment where !appendFragment.isEmpty else { return nil }
        var new = fragment ?? ""
        if !new.isEmpty {
            new = new.finish(";")
        }
        return new + appendFragment
    }

    public func appended(query appendQuery: String?) -> String? {
        guard let appendQuery = appendQuery where !appendQuery.isEmpty else { return nil }

        var new = query ?? ""
        if !new.isEmpty {
            new = new.finish("&")
        }
        return new + appendQuery
    }
}
