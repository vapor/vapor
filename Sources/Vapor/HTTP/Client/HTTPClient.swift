import Socks
import SocksCore

public enum HTTPClientError: ErrorProtocol {
    case missingHost
    case missingPort
}

public final class HTTPClient<Stream: ClientStream>: HTTPClientProtocol {
    public init() {}
    
    public func request(_ method: Method,
                        url: String,
                        headers: Headers = [:],
                        query: [String: String] = [:],
                        body: HTTPBody = .data([])) throws -> HTTPResponse {
        let endpoint = url.finish("/")
        var uri = try URI(endpoint)
        uri.append(query: query)

        // TODO: Is it worth exposing Version? We don't support alternative serialization/parsing
        let version = Version(major: 1, minor: 1)
        let request = HTTPRequest(method: method, uri: uri, version: version, headers: headers, body: body)
        let connection = try makeConnection(to: uri)
        return try perform(request, with: connection)
    }

    private func perform(_ request: HTTPRequest, with connection: Vapor.Stream) throws -> HTTPResponse {
        let serializer = HTTPSerializer<Request>(stream: connection)
        try serializer.serialize(request)
        let parser = HTTPParser<HTTPResponse>(stream: connection)
        let response = try parser.parse()
        _ = try? connection.close() // TODO: Support keep-alive?
        return response
    }

    private func makeConnection(to uri: URI) throws -> Vapor.Stream {
        guard let host = uri.host else { throw HTTPClientError.missingHost }
        guard let port = uri.port ?? uri.schemePort else { throw HTTPClientError.missingPort }

        let useSSL = uri.scheme?.hasSuffix("s") == true
        let client = try Stream.makeConnection(host: host, port: port, usingSSL: useSSL)
        let buffer = StreamBuffer(client)
        return buffer
    }
}
