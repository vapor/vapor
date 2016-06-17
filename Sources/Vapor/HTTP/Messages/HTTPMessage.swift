public protocol HTTPMessage: class {
    var startLine: String { get }
    var headers: Headers { get set }
    var body: HTTP.Body { get }

    // MARK: Extensibility

    var data: Content { get }
    var storage: [String: Any] { get set }
    
    init(startLineComponents: (BytesSlice, BytesSlice, BytesSlice), headers: Headers, body: HTTP.Body) throws
}

extension HTTPMessage {
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

extension HTTPMessage {
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
