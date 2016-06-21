import Socks
import SocksCore

public enum HTTPClientError: ErrorProtocol {
    case missingHost
    case missingPort
}

public final class HTTPClient<ClientStreamType: ClientStream>: Client {
    public let client: ClientStreamType
    public let host: String
    public var stream: Stream

    public init(scheme: String, host: String, port: Int) throws {
        self.host = host
        let client = try ClientStreamType(scheme: scheme, host: host, port: port)
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
        if stream.closed {
            stream = try client.connect()
        }
        let buffer = StreamBuffer(stream)

        request.headers["Host"] = host

        let serializer = HTTPSerializer<Request>(stream: buffer)
        try serializer.serialize(request)

        let parser = HTTPParser<HTTPResponse>(stream: buffer)
        let response = try parser.parse()

        try buffer.flush()
        return response
    }
}
