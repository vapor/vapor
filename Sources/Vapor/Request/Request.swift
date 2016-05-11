extension Request {
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
    private func parseCookies(_ string: String) -> [String: String] {
        var cookies: [String: String] = [:]

        let cookieTokens = string.split(byString: ";")
        for cookie in cookieTokens {
            let cookieArray = cookie.split(byString: "=")

            if cookieArray.count == 2 {
                let split = cookieArray[0].split(byString: " ")
                let key = split.joined(separator: "")
                let validKey = String(validatingUTF8: key) ?? ""
                cookies[validKey] = String(validatingUTF8: cookieArray[1])
            }
        }

        return cookies
    }

    private func parseFormEncoded(_ string: String) -> [String: String] {
        var formEncoded: [String: String] = [:]

        for pair in string.split(byString: "&") {
            let token = pair.split(separator: "=", maxSplits: 1)
            if token.count == 2 {
                let key = String(validatingUTF8: token[0]) ?? ""
                var value = String(validatingUTF8: token[1]) ?? ""
                value = (try? String(percentEncoded: value)) ?? ""
                formEncoded[key] = value
            }
        }

        return formEncoded
    }

    mutating func parseData() {
        data = parseContent()
    }

    private func parseContent() -> Request.Content {
        var queries: [String: String] = [:]
        uri.query.forEach { (key, queryField) in
            queries[key] = queryField
                .values
                .flatMap { $0 }
                .joined(separator: ",")
        }

        var json: Json?
        var formEncoded: [String: String]?
        var mutableBody = body

        if headers["Content-Type"].first == "application/json" {
            do {
                let data = try mutableBody.becomeBuffer()
                json = try Json(data)
            } catch {
                Log.warning("Could not parse JSON: \(error)")
            }
        } else {
            do {
                let data = try mutableBody.becomeBuffer()
                let string = try String(data: data)
                formEncoded = parseFormEncoded(string)
            } catch {
                Log.warning("Could not parse form encoded data: \(error)")
            }
        }

        return Request.Content(query: queries, json: json, formEncoded: formEncoded)
    }

    ///Query data from the path, or POST data from the body (depends on `Method`).
    public var data: Request.Content {
        get {
            guard let data = storage["data"] as? Request.Content else {
                Log.warning("Data has not been parsed.")
                return Request.Content(query: [:], json: nil, formEncoded: nil)
            }

            return data
        }
        set(data) {
            storage["data"] = data
        }
    }

    public struct Handler: Responder {
        public typealias Closure = Request throws -> Response

        let closure: Closure

        /**
         Respond to a given request or throw if fails

         - parameter request: request to respond to

         - throws: an error if response fails

         - returns: a response if possible
         */
        public func respond(to request: Request) throws -> Response {
            return try closure(request)
        }
    }
}
