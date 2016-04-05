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
        var cookies: [String: String] = [:]

        for cookieString in headers["Cookie"] {
            for (key, val) in parseCookies(cookieString) {
                cookies[key] = val
            }
        }

        return cookies

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

        var json: Json?

        if headers["Content-Type"].first == "application/json" {
            var mutableBody = body
            do {
                let data = try mutableBody.becomeBuffer()
                json = try Json(data)
            } catch {
                Log.warning("Could not parse JSON: \(error)")
            }
        }

        return Request.Content(query: queries, json: json)
    }
}
