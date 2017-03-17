import Node
import HTTP

extension Message {
    /// form url encoded encoded request data
    public var formURLEncoded: Node? {
        get {
            if let existing = storage["form-urlencoded"] as? Node {
                return existing
            } else if let type = headers[.contentType], type.contains("application/x-www-form-urlencoded") {
                guard case let .data(body) = body else { return nil }
                let formURLEncoded = Node(formURLEncoded: body, allowEmptyValues: false)
                storage["form-urlencoded"] = formURLEncoded
                return formURLEncoded
            } else {
                return nil
            }
        }
        
        set(data) {
            storage["form-urlencoded"] = data

            if let data = data, let bytes = try? data.formURLEncoded() {
                body = .data(bytes)
                headers[.contentType] = "application/x-www-form-urlencoded"
            } else if let type = headers[.contentType], type.contains("application/x-www-form-urlencoded") {
                body = .data([])
                headers.removeValue(forKey: .contentType)
            }
        }
    }
}

extension Request {
    /// Query data from the URI path
    public var query: Node? {
        get {
            if let existing = storage["query"] {
                return existing as? Node
            } else if let queryRaw = uri.rawQuery {
                let queryBytes = queryRaw.makeBytes()
                let query = Node(formURLEncoded: queryBytes, allowEmptyValues: true)
                storage["query"] = query
                return query
            } else {
                return nil
            }
        }
        set(data) {
            if let data = data {
                do {
                    uri.query = try data.formURLEncoded().makeString()
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
