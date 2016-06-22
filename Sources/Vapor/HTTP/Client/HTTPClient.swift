public enum HTTPClientError: ErrorProtocol {
    case missingHost
    case unableToConnect
}

public protocol AAAAAltClientProtocol: Responder {
    var host: String { get }
    var port: Int { get }
    var scheme: String { get }
    var stream: Stream { get }
    init(scheme: String, host: String, port: Int) throws
}

public enum SDFERR: ErrorProtocol {
    case invalidRequestHost
    case invalidRequestScheme
    case invalidRequestPort
    case userInfoNotAllowedOnHTTP
}

public final class asdf<ClientStreamType: ClientStream>: AAAAAltClientProtocol {

    public let scheme: String
    public let host: String
    public let port: Int
    public let stream: Stream


    public init(scheme: String, host: String, port: Int) throws {
        self.scheme = scheme
        self.host = host
        self.port = port
        let securityLayer = host.securityLayer ?? .tls // Default to secure -- opt out
        let client = try ClientStreamType(host: host, port: port, securityLayer: securityLayer)
        let stream = try client.connect()
        self.stream = StreamBuffer(stream)
    }

    public func respond(to request: Request) throws -> Response {
        try assertValid(request)
        guard !stream.closed else { throw HTTPClientError.unableToConnect }

        /*
             A client MUST send a Host header field in all HTTP/1.1 request
             messages.  If the target URI includes an authority component, then a
             client MUST send a field-value for Host that is identical to that
             authority component, excluding any userinfo subcomponent and its "@"
             delimiter (Section 2.7.1).  If the authority component is missing or
             undefined for the target URI, then a client MUST send a Host header
             field with an empty field-value.
        */
        request.headers["Host"] = host

        let serializer = HTTPSerializer<Request>(stream: stream)
        try serializer.serialize(request)

        let parser = HTTPParser<Response>(stream: stream)
        let response = try parser.parse()

        return response
    }

    private func assertValid(_ request: Request) throws {
        if !request.uri.host.isNilOrEmpty {
            guard request.uri.host == host else { throw SDFERR.invalidRequestHost }
        }

        if !request.uri.scheme.isNilOrEmpty {
            guard request.uri.scheme == scheme else { throw SDFERR.invalidRequestScheme }
        }

        if let requestPort = request.uri.port {
            guard requestPort == port else { throw SDFERR.invalidRequestPort }
        }

        guard request.uri.userInfo == nil else {
            /*
                 Userinfo (i.e., username and password) are now disallowed in HTTP and
                 HTTPS URIs, because of security issues related to their transmission
                 on the wire.  (Section 2.7.1)
            */
            throw SDFERR.userInfoNotAllowedOnHTTP
        }
    }
}

extension AAAAAltClientProtocol {
    public static func make(scheme: String = "https", host: String, port: Int? = nil) throws -> Self {
        let port = port ?? URI.defaultPorts[scheme] ?? 80
        return try Self(scheme: scheme, host: host, port: port)
    }
}

extension AAAAAltClientProtocol {
    public func request(_ method: Vapor.Method, path: String, headers: Headers = [:], query: [String: StructuredDataRepresentable], body: Vapor.HTTPBody = []) throws -> Response {
        var uri = URI(scheme: scheme, userInfo: nil, host: host, port: port, path: path, query: nil, fragment: nil)
        uri.append(query: StructuredData(query))
        let request = Request(method: method, uri: uri, version: Version(major: 1, minor: 1), headers: headers, body: body)
        return try respond(to: request)
    }

    public func get(path: String, headers: Headers = [:], query: [String: String], body: Vapor.HTTPBody = []) throws -> Response {
        return try request(.get, path: path, headers: headers, query: query, body: body)
    }

    public func post(path: String, headers: Headers = [:], query: [String: String], body: Vapor.HTTPBody = []) throws -> Response {
        return try request(.post, path: path, headers: headers, query: query, body: body)
    }

    public func put(path: String, headers: Headers = [:], query: [String: String], body: Vapor.HTTPBody = []) throws -> Response {
        return try request(.put, path: path, headers: headers, query: query, body: body)
    }

    public func patch(path: String, headers: Headers = [:], query: [String: String], body: Vapor.HTTPBody = []) throws -> Response {
        return try request(.patch, path: path, headers: headers, query: query, body: body)
    }

    public func delete(_ path: String, headers: Headers = [:], query: [String: String], body: Vapor.HTTPBody = []) throws -> Response {
        return try request(.delete, path: path, headers: headers, query: query, body: body)
    }
}

extension AAltClientProtocol {
    public static func respond(to request: Request) throws -> Response {
        let instance = try Self.init(existingConnection: nil)
        return try instance.respond(to: request)
    }

    public static func request(_ method: Vapor.Method, _ uri: String, headers: Headers = [:], query: [String: StructuredDataRepresentable], body: Vapor.HTTPBody = []) throws -> Response {
        var uri = try URI(uri)
        let structure = StructuredData(query)
        uri.append(query: structure)
        let request = Request(method: method, uri: uri, headers: headers, body: body)
        return try respond(to: request)
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

public final class AAAAAAltClient<ClientStreamType: ClientStream>: AAltClientProtocol {
    public typealias ClientStreamTyp = ClientStreamType
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
        // TODO: If no connection established, we establish a new one. 
        // This feels like the right thing to do
        // but should be considered
        if let connection = connection where !connection.closed {
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
