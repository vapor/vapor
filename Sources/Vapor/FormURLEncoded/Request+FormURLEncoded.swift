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
                // TODO: Is there a way to avoid the downward dependency on
                //       Request here?
                let formURLEncoded = Node(formURLEncoded: body, distinguishingEmptyValues: Request.distinguishEmptyFormURLEncodedValues)
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

// TODO: Is a fileprivate global the best place to store this value?
fileprivate var requestsAreDistinguishingEmptyFormURLEncodedValues: Bool = false

extension Request {
    /// Whether to explicitly represent form-urlencoded parameters with empty or
    /// absent values, or to omit them altogether. Despite its location in this
    /// source file, this setting applies ONLY to parsing of
    /// application/x-www-form-urlencoded requests; it does NOT apply to parsing
    /// of query strings in a URL, nor to requests using multipart/form-data
    /// encoding.
    public internal(set) static var distinguishEmptyFormURLEncodedValues: Bool {
    // TODO: Should this be publicly settable for droplets that don't wish to
    //       set it in droplet.json?
    // TODO: Should we just make the fileprivate global available instead, or
    //       maybe create a RequestConfig class?
    // TODO: While we have to honor this setting only for form-urlencoded form
    //       submissions or else break backwards compat, it seems confusing to
    //       ignore it for query string parsing. Is there a better paradigm?
    //       Possibly separately configurable behaviors?
        get { return requestsAreDistinguishingEmptyFormURLEncodedValues }
        set { requestsAreDistinguishingEmptyFormURLEncodedValues = newValue }
    }

    /// Query data from the URI path
    public var query: Node? {
        get {
            if let existing = storage["query"] {
                return existing as? Node
            } else if let queryRaw = uri.query {
                let queryBytes = queryRaw
                    .makeBytes()
                let query = Node(formURLEncoded: queryBytes)
                storage["query"] = query
                return query
            } else {
                return nil
            }
        }
        set(data) {
            if let data = data, let query = try? data.formURLEncoded(), !query.isEmpty {
                uri.query = query.makeString()
                storage["query"] = data
            } else {
                storage["query"] = nil
                uri.query = nil
            }
        }
    }
}
