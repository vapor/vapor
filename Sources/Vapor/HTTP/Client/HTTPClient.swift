import Socks
import SocksCore

public enum HTTPClientError: ErrorProtocol {
    case missingHost
    case missingPort
}

public final class HTTPClient<ClientStreamType: ClientStream>: Client {
    public let client: ClientStreamType
    public var stream: Stream
    public let host: String

    public init(scheme: String, host: String, port: Int) throws {
        self.host = host
        client = try ClientStreamType(scheme: scheme, host: host, port: port)
        stream = try client.connect()
    }

    public func respond(to request: Request) throws -> Response {
        request.headers["Host"] = host
        request.headers["Content-Length"] = 0.description

        let serializer = HTTPSerializer<Request>(stream: stream)
        try serializer.serialize(request)

        let parser = HTTPParser<HTTPResponse>(stream: stream)
        let response = try parser.parse()

        return response
    }
}
