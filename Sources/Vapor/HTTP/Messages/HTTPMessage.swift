extension HTTP {
    public class Message {
        public let startLine: String
        public var headers: Headers

        // Settable for HEAD request -- evaluate alternatives -- Perhaps serializer should handle it.
        // must NOT be exposed public because changing body will break behavior most of time
        public internal(set) var body: HTTP.Body

        public var storage: [String: Any] = [:]
        public private(set) final lazy var data: Content = Content(self)

        public convenience required init(startLineComponents: (BytesSlice, BytesSlice, BytesSlice),
                                headers: Headers,
                                body: HTTP.Body) throws {
            let startLine = startLineComponents.0.string
                + " "
                + startLineComponents.1.string
                + " "
                + startLineComponents.2.string

            self.init(startLine: startLine, headers: headers,body: body)
        }

        public init(startLine: String, headers: Headers, body: HTTP.Body) {
            self.startLine = startLine
            self.headers = headers
            self.body = body
        }
    }
}

extension HTTP.Message {
    public var contentType: String? {
        return headers["Content-Type"]
    }
    public var keepAlive: Bool {
        // HTTP 1.1 defaults to true unless explicitly passed `Connection: close`
        guard let value = headers["Connection"] else { return true }
        // TODO: Decide on if 'contains' is better, test linux version
        return !value.contains("close")
    }
}

extension HTTP.Message {
    public var json: JSON? {
        if let existing = storage["json"] as? JSON {
            return existing
        } else if let type = headers["Content-Type"] where type.contains("application/json") {
            guard case let .data(body) = body else { return nil }
            guard let json = try? JSON.deserializer(data: body) else { return nil }
            storage["json"] = json
            return json
        } else {
            return nil
        }
    }
}
