import S4

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
            for (key, val) in Request.parseCookies(cookieString) {
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
    static private func parseCookies(_ string: String) -> [String: String] {
        var cookies: [String: String] = [:]

        let cookieTokens = string.components(separatedBy: ";")
        for cookie in cookieTokens {
            let cookieArray = cookie.components(separatedBy: "=")

            if cookieArray.count == 2 {
                let split = cookieArray[0].components(separatedBy: " ")
                let key = split.joined(separator: "")
                let validKey = String(validatingUTF8: key) ?? ""
                cookies[validKey] = String(validatingUTF8: cookieArray[1])
            }
        }

        return cookies
    }

    mutating func cacheParsedContent() {
        data = parseContent()
    }

    func parseContent() -> Request.Content {
        var data: Data?
        var mutableBody = body

        do {
            data = try mutableBody.becomeBuffer()
        } catch {
            Log.error("Could not read body: \(error)")
        }

        return Request.parseContent(data, uri: uri, headers: headers)
    }

    static private func parseContent(_ data: Data?, uri: URI, headers: Headers) -> Request.Content {
        let query = parseQuery(uri: uri)

        var json: JSON?
        var formEncoded: StructuredData?
        var multipart: [String: MultiPart]?

        if
            let contentType = headers["Content-Type"].first,
            let data = data
        {
            if contentType.range(of: "application/json") != nil {
                do {
                    json = try JSON(data)
                } catch {
                    Log.warning("Could not parse JSON: \(error)")
                }
            } else if contentType.range(of: "multipart/form-data") != nil {
                do {
                    let boundary = try Request.parseBoundary(contentType: contentType)
                    multipart = Request.parseMultipartForm(data, boundary: boundary)
                } catch {
                    Log.warning("Could not parse MultiPart: \(error)")
                }
            } else if contentType.range(of: "application/x-www-form-urlencoded") != nil {
                formEncoded = Request.parseFormURLEncoded(data)
            }
        }

        return Request.Content(query: query, json: json, formEncoded: formEncoded, multipart: multipart)
    }

    static func parseQuery(uri: URI) -> StructuredData {
        var query: [String: StructuredData] = [:]

        uri.query.forEach { (key, values) in
            let string = values
                .flatMap { $0 }
                .joined(separator: ",")
            query[key] = .string(string)
        }

        return .dictionary(query)
    }

    ///Query data from the path, or POST data from the body (depends on `Method`).
    public var data: Request.Content {
        get {
            guard let data = storage["data"] as? Request.Content else {
                Log.warning("Data has not been cached.")
                return parseContent()
            }

            return data
        }
        set(data) {
            storage["data"] = data
        }
    }

    public struct Handler: Responder {
        public typealias Closure = (Request) throws -> Response

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

extension Data {
    func split(separator: Data, excludingFirst: Bool = false, excludingLast: Bool = false) -> [Data] {
        var ranges = [(from: Int, to: Int)]()
        var parts = [Data]()

        // "\r\n\r\n\r\n".split(separator: "\r\n\r\n") would break without this because it occurs twice in the same place
        var highestOccurence = -1

        // Find occurences of boundries
        for (index, element) in self.enumerated() where index > highestOccurence {
            // If this first element matches and there are enough bytes left
            guard element == separator.first && self.count >= index + separator.count else {
                continue
            }

            // Take the last byte of where the end of the separator would be and check it
            guard self[index + separator.count - 1] == separator.bytes.last else {
                continue
            }

            // Check if this range matches (put separately for efficiency)
            guard Data(self[index..<(index+separator.count)]) == separator else {
                continue
            }
            
            // Append the range of the separator
            ranges.append((index, index + separator.count))

            // Increase the highest occurrence to prevent a crash as described above
            highestOccurence = index + separator.count
        }

        // The first data (before the first separator)
        if let firstRange = ranges.first where !excludingFirst {
            parts.append(Data(self[0..<firstRange.from]))
        }

        // Loop over the ranges
        for (pos, range) in ranges.enumerated() {
            // If this is before the last separator
            if pos < ranges.count - 1 {
                // Take the data inbetween this and the next boundry
                let nextRange = ranges[pos + 1]

                parts.append(Data(self[range.to..<nextRange.from]))

            // If this is after the last separator and shouldn't be thrown away
            } else if ranges[ranges.count - 1].to < self.count && !excludingLast {
                parts.append(Data(self[range.to..<self.count]))
            }
        }

        return parts
    }
}
