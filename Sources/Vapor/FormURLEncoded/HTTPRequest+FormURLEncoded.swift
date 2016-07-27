import Node
import Engine

extension HTTPRequest {
    /// form url encoded encoded request data
    public var formURLEncoded: Node? {
        if let existing = storage["form-urlencoded"] as? Node {
            return existing
        } else if let type = headers["Content-Type"], type.contains("application/x-www-form-urlencoded") {
            guard case let .data(body) = body else { return nil }
            let formURLEncoded = Node(formURLEncoded: body)
            storage["form-urlencoded"] = formURLEncoded
            return formURLEncoded
        } else {
            return nil
        }
    }
}

extension HTTPRequest {
    /// Query data from the URI path
    public var query: Node? {
        get {
            if let existing = storage["query"] {
                return existing as? Node
            } else if let queryRaw = uri.query {
                let query = Node(formURLEncoded: queryRaw.bytes)
                storage["query"] = query
                return query
            } else {
                return nil
            }
        }
        set(data) {
            if let data = data {
                do {
                    uri.query = try data.formURLEncoded().string
                    storage["query"] = data
                } catch {
                    // make no changes
                }
            } else {
                uri.query = nil
            }
        }
    }
}
