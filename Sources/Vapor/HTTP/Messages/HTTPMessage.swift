public enum HTTPMessageError: ErrorProtocol {
    case invalidStartLine
}

public class HTTPMessage {
    public let startLine: String
    public var headers: Headers

    // Settable for HEAD request -- evaluate alternatives -- Perhaps serializer should handle it.
    // must NOT be exposed public because changing body will break behavior most of time
    public internal(set) var body: HTTPBody

    public var storage: [String: Any] = [:]
    public private(set) final lazy var data: Content = Content(self)

    public convenience required init(
        startLineComponents: (BytesSlice, BytesSlice, BytesSlice),
        headers: Headers,
        body: HTTPBody
    ) throws {
        let startLine = startLineComponents.0.string
            + " "
            + startLineComponents.1.string
            + " "
            + startLineComponents.2.string

        self.init(startLine: startLine, headers: headers,body: body)
    }

    public init(startLine: String, headers: Headers, body: HTTPBody) {
        self.startLine = startLine
        self.headers = headers
        self.body = body
    }
}

extension HTTPMessage: TransferMessage {}

extension HTTPMessage {
    public var contentType: String? {
        return headers["Content-Type"]
    }
    public var keepAlive: Bool {
        // HTTP 1.1 defaults to true unless explicitly passed `Connection: close`
        guard let value = headers["Connection"] else { return true }
        return !value.contains("close")
    }
}

extension HTTPMessage {
    public var json: JSON? {
        if let existing = storage["json"] as? JSON {
            return existing
        } else if let type = headers["Content-Type"] where type.contains("application/json") {
            guard case let .data(body) = body else { return nil }
            guard let json = try? JSON.parse(body) else { return nil }
            storage["json"] = json
            return json
        } else {
            return nil
        }
    }
}
