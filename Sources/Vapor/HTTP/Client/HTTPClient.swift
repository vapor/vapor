import Socks
import SocksCore

public final class Client: ClientDriver {
    public static let shared: Client = .init()

    public func request(_ method: Method,
                        url: String,
                        headers: Headers = [:],
                        query: [String: String] = [:],
                        body: HTTP.Body = .data([])) throws -> HTTP.Response {
        let endpoint = url.finish("/")
        var uri = try URI(endpoint)
        uri.append(query: query)

        // TODO: Is it worth exposing Version? We don't support alternative serialization/parsing
        let version = Version(major: 1, minor: 1)
        let request = HTTP.Request(method: method, uri: uri, version: version, headers: headers, body: body)
        let connection = try makeConnection(to: uri)
        return try perform(request, with: connection)
    }

    private func perform(_ request: HTTP.Request, with connection: Vapor.Stream) throws -> HTTP.Response {
        let serializer = HTTP.Serializer(stream: connection)
        try serializer.serialize(request)
        let parser = HTTP.Parser(stream: connection)
        let response = try parser.parse(HTTP.Response.self)
        _ = try? connection.close() // TODO: Support keep-alive?
        return response
    }

    private func makeConnection(to uri: URI) throws -> Vapor.Stream {
        guard
            let host = uri.host,
            let port = uri.port
                ?? uri.schemePort
            else { fatalError("throw appropriate error, missing port") }
        let address = InternetAddress(hostname: host, port: Port(port))
        let client = try TCPClient(address: address)
        let buffer = StreamBuffer(client)
        return buffer
    }
}
