public enum HTTPClientError: ErrorProtocol {
    case missingHost
    case unableToConnect
}

public protocol AltClientProtocol: Responder {
    init(existingConnection: Stream?) throws
}

extension AltClientProtocol {
    public static func perform(_ request: Request) throws -> Response {
        let instance = try Self.init(existingConnection: nil)
        return try instance.respond(to: request)
    }

    public static func request(_ method: Vapor.Method, _ uri: String, headers: Headers = [:], query: [String: StructuredDataRepresentable], body: Vapor.HTTPBody = []) throws -> Response {
        var uri = try URI(uri)
        let structure = StructuredData(query)
        uri.append(query: structure)
        let request = Request(method: method, uri: uri, headers: headers, body: body)
        return try perform(request)
    }

    public static func get(_ uri: String, headers: Headers = [:], query: [String: String], body: Vapor.HTTPBody = []) throws -> Response {
        return try request(.get, uri, headers: headers, query: query, body: body)
    }

    public static func post(_ uri: String, headers: Headers = [:], query: [String: String], body: Vapor.HTTPBody = []) throws -> Response {
        return try request(.post, uri, headers: headers, query: query, body: body)
    }

    public static func put(_ uri: String, headers: Headers = [:], query: [String: String], body: Vapor.HTTPBody = []) throws -> Response {
        return try request(.put, uri, headers: headers, query: query, body: body)
    }

    public static func patch(_ uri: String, headers: Headers = [:], query: [String: String], body: Vapor.HTTPBody = []) throws -> Response {
        return try request(.patch, uri, headers: headers, query: query, body: body)
    }

    public static func delete(_ uri: String, headers: Headers = [:], query: [String: String], body: Vapor.HTTPBody = []) throws -> Response {
        return try request(.delete, uri, headers: headers, query: query, body: body)
    }
}

public final class AAAAAAltClient<ClientStreamType: ClientStream>: AltClientProtocol {
    public private(set) var connection: Stream?

    public init(existingConnection: Stream? = nil) throws {
        self.connection = existingConnection
    }

    public func respond(to request: Request) throws -> Response {
        let stream = try getConnection(to: request.uri)
        guard !stream.closed else { throw HTTPClientError.unableToConnect }
        let buffer = StreamBuffer(stream)

        request.headers["Host"] = request.uri.host

        let serializer = HTTPSerializer<Request>(stream: buffer)
        try serializer.serialize(request)

        let parser = HTTPParser<Response>(stream: buffer)
        let response = try parser.parse()

        try buffer.flush()
        return response
    }

    private func getConnection(to uri: URI) throws -> Stream {
        if let connection = connection {
            return connection
        } else {
            guard let host = uri.host else { throw HTTPClientError.missingHost }
            let port = uri.port ?? uri.schemePort ?? 80
            let securityLayer = uri.scheme?.securityLayer ?? .tls // Default to secure -- opt out
            let client = try ClientStreamType(host: host, port: port, securityLayer: securityLayer)
            let stream = try client.connect()
            connection = stream
            return stream
        }
    }
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
