//public enum ClientError: ErrorProtocol {
//    case missingHost
//}
//
//public protocol Client: Program, Responder {
//    var stream: Stream { get }
//}
//
//extension Client {
//    public func request(_ method: Vapor.Method, path: String, headers: Headers = [:], query: [String: StructuredDataRepresentable] = [:], body: Vapor.HTTPBody = []) throws -> Response {
//        // TODO: Move finish("/") to initializer
//        var uri = URI(scheme: "", userInfo: nil, host: host, port: port, path: path.finish("/"), query: nil, fragment: nil)
//        uri.append(query: StructuredData(query))
//        let request = Request(method: method, uri: uri, version: Version(major: 1, minor: 1), headers: headers, body: body)
//        return try respond(to: request)
//    }
//
//    public func get(path: String, headers: Headers = [:], query: [String: StructuredDataRepresentable] = [:], body: Vapor.HTTPBody = []) throws -> Response {
//        return try request(.get, path: path, headers: headers, query: query, body: body)
//    }
//
//    public func post(path: String, headers: Headers = [:], query: [String: StructuredDataRepresentable] = [:], body: Vapor.HTTPBody = []) throws -> Response {
//        return try request(.post, path: path, headers: headers, query: query, body: body)
//    }
//
//    public func put(path: String, headers: Headers = [:], query: [String: StructuredDataRepresentable] = [:], body: Vapor.HTTPBody = []) throws -> Response {
//        return try request(.put, path: path, headers: headers, query: query, body: body)
//    }
//
//    public func patch(path: String, headers: Headers = [:], query: [String: StructuredDataRepresentable] = [:], body: Vapor.HTTPBody = []) throws -> Response {
//        return try request(.patch, path: path, headers: headers, query: query, body: body)
//    }
//
//    public func delete(_ path: String, headers: Headers = [:], query: [String: StructuredDataRepresentable] = [:], body: Vapor.HTTPBody = []) throws -> Response {
//        return try request(.delete, path: path, headers: headers, query: query, body: body)
//    }
//}
//
//extension Client {
//    public static func respond(to request: Request) throws -> Response {
//        guard let host = request.uri.host else { throw ClientError.missingHost }
//        let instance = try make(scheme: request.uri.scheme, host: host, port: request.uri.port)
//        return try instance.respond(to: request)
//    }
//
//    public static func make(scheme: String? = nil, host: String, port: Int? = nil) throws -> Client {
//        let scheme = scheme ?? "https" // default to secure https connection
//        let port = port ?? URI.defaultPorts[scheme] ?? 80
//        return try make(host: host, port: port, securityLayer: scheme.securityLayer)
//    }
//
//    public static func request(
//        _ method: Vapor.Method,
//        _ uri: String,
//        headers: Headers = [:],
//        query: [String: StructuredDataRepresentable],
//        body: Vapor.HTTPBody = []
//    ) throws -> Response {
//        var uri = try URI(uri)
//        let structure = StructuredData(query)
//        // Always append query incase URI also contains query
//        uri.append(query: structure)
//        let request = Request(method: method, uri: uri, headers: headers, body: body)
//        return try respond(to: request)
//    }
//
//    public static func get(
//        _ uri: String,
//        headers: Headers = [:],
//        query: [String: StructuredDataRepresentable] = [:],
//        body: Vapor.HTTPBody = []
//    ) throws -> Response {
//        return try request(.get, uri, headers: headers, query: query, body: body)
//    }
//
//    public static func post(
//        _ uri: String,
//        headers: Headers = [:],
//        query: [String: StructuredDataRepresentable] = [:],
//        body: Vapor.HTTPBody = []
//    ) throws -> Response {
//        return try request(.post, uri, headers: headers, query: query, body: body)
//    }
//
//    public static func put(
//        _ uri: String,
//        headers: Headers = [:],
//        query: [String: StructuredDataRepresentable] = [:],
//        body: Vapor.HTTPBody = []
//    ) throws -> Response {
//        return try request(.put, uri, headers: headers, query: query, body: body)
//    }
//
//    public static func patch(
//        _ uri: String,
//        headers: Headers = [:],
//        query: [String: StructuredDataRepresentable] = [:],
//        body: Vapor.HTTPBody = []
//    ) throws -> Response {
//        return try request(.patch, uri, headers: headers, query: query, body: body)
//    }
//
//    public static func delete(
//        _ uri: String,
//        headers: Headers = [:],
//        query: [String: StructuredDataRepresentable] = [:],
//        body: Vapor.HTTPBody = []
//    ) throws -> Response {
//        return try request(.delete, uri, headers: headers, query: query, body: body)
//    }
//}
