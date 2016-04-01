extension Request {
    public typealias Handler = ((request: Request) throws -> Response)

    ///URL parameters (ex: `:id`).
    public var parameters: [String: String] {
        get {
            guard let parameters = storage["parameters"] as? [String: String] else {
                return [:]
            }

            return parameters
        }
        set(parameters) {
            storage["parameters"] = parameters
        }
    }

    ///Server stored information related from session cookie.
    public var session: Session? {
        get {
            return storage["session"] as? Session
        }
        set(session) {
            storage["session"] = session
        }
    }

    ///Browser stored data sent with every server request
    public var cookies: [String: String] {
        guard let cookies = headers["Cookie"].first else {
            return [:]
        }

        return parseCookies(cookies)
    }

    public init(method: Method = .get, path: String, host: String? = nil, body: Data = []) {
        self.init(method: method, uri: URI(path: path, host: host), headers: [:], body: body)
    }

    /**
        Cookies are sent to the server as `key=value` pairs
        separated by semicolons.

        - returns: String dictionary of parsed cookies.
     */
    private func parseCookies(string: String) -> [String: String] {
        var cookies: [String: String] = [:]

        let cookieTokens = string.split(";")
        for cookie in cookieTokens {
            let cookieArray = cookie.split("=")

            if cookieArray.count == 2 {
                let split = cookieArray[0].split(" ")
                let key = split.joined(separator: "")
                cookies[key] = cookieArray[1]
            }
        }

        return cookies
    }

    ///Query data from the path, or POST data from the body (depends on `Method`).
    public var data: Request.Content {
        var queries: [String: String] = [:]
        uri.query.forEach { query in
            queries[query.key] = query.value
        }
        return Request.Content(query: queries, body: body)
    }
}

extension String {
    
    /**
        Query data is information appended to the URL path
        as `key=value` pairs separated by `&` after
        an initial `?`

        - returns: String dictionary of parsed Query data
     */
    internal func queryData() -> [String: String] {
        // First `?` indicates query, subsequent `?` should be included as part of the arguments
        return split("?", maxSplits: 1)
            .dropFirst()
            .reduce("", combine: +)
            .keyValuePairs()
    }
    
    /**
        Parses `key=value` pair data separated by `&`.

        - returns: String dictionary of parsed data
     */
    internal func keyValuePairs() -> [String: String] {
        var data: [String: String] = [:]
        
        for pair in self.split("&") {
            let tokens = pair.split("=", maxSplits: 1)
            
            if
                let name = tokens.first,
                let value = tokens.last,
                let parsedName = try? String(percentEncoded: name) {
                data[parsedName] = try? String(percentEncoded: value)
            }
        }
        
        return data
    }
    
}
