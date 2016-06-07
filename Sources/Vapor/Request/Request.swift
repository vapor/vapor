import S4






class JSONMiddleware: S4.Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        var request = request
        if request.headers["content-type"]?.range(of: "application/json") != nil {
            do {
                let data = try request.body.becomeBuffer()
                request.json = try JSON(data)
            } catch {
                Log.warning("Could not parse JSON: \(error)")
            }
        }

        var response = try next.respond(to: request)

        if let json = response.json {
            response.headers["content-type"] = "application/json"
            response.body = .buffer(json.data)
        }

        return response
    }
}

extension Response {
    public var json: JSON? {
        get {
            return storage["json"] as? JSON
        }
        set(data) {
            storage["json"] = data
        }
    }

    /**
        Convenience Initializer

        - parameter status: the http status
        - parameter json: any value that will be attempted to be serialized as json.  Use 'Json' for more complex objects
     */
    public init(status: Status, json: JSON) {
        let headers: Headers = [
            "Content-Type": "application/json"
        ]
        self.init(status: status, headers: headers, body: json.data)
    }
}



extension Request {
    /// JSON encoded request data
    public var json: JSON? {
        get {
            return storage["json"] as? JSON
        }
        set(data) {
            storage["json"] = data
        }
    }
}










class FormURLEncodedMiddleware: S4.Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        var request = request

        if request.headers["content-type"]?.range(of: "application/x-www-form-urlencoded") != nil {
            do {
                let data = try request.body.becomeBuffer()
                request.formURLEncoded = Request.parseFormURLEncoded(data)
            } catch {
                Log.warning("Could not parse Form-URLEncoded: \(error)")
            }

        }

        return try next.respond(to: request)
    }
}

extension Request {
    /// JSON encoded request data
    public var formURLEncoded: StructuredData? {
        get {
            return storage["form-urlencoded"] as? StructuredData
        }
        set(data) {
            storage["form-urlencoded"] = data
        }
    }
}






class MultipartMiddleware: S4.Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        var request = request

        if let contentType = request.headers["content-type"] where contentType.range(of: "multipart/form-data") != nil {
            do {
                let data = try request.body.becomeBuffer()
                let boundary = try Request.parseBoundary(contentType: contentType)
                request.multipart = Request.parseMultipartForm(data, boundary: boundary)
            } catch {
                Log.warning("Could not parse MultiPart: \(error)")
            }
        }

        return try next.respond(to: request)
    }
}

extension Request {
    /// JSON encoded request data
    public var multipart: [String: MultiPart]? {
        get {
            return storage["multipart"] as? [String: MultiPart]
        }
        set(data) {
            storage["multipart"] = data
        }
    }
}






class ContentMiddleware: S4.Middleware {

    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        var request = request

        let query = Request.parseQuery(uri: request.uri)
        request.data = Request.Content(query: query, request: request)
        request.query = query

        return try next.respond(to: request)
    }

}

extension Request {
    public var query: StructuredData? {
        get {
            return storage["query"] as? StructuredData
        }
        set(data) {
            storage["query"] = data
        }
    }
    ///Query data from the path, or POST data from the body (depends on `Method`).
    public var data: Request.Content {
        get {
            guard let content = storage["content"] as? Request.Content else {
                Log.warning("Request Content not parsed, make sure the middleware is installed.")
                return Request.Content(query: .null, request: self)
            }

            return content
        }
        set(data) {
            storage["content"] = data
        }
    }
}











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

    public init(method: Method = .get, path: String, host: String? = nil, body: Data = []) {
        self.init(method: method, uri: URI(path: path, host: host), headers: [:], body: body)
    }

    /**
        Cookies are sent to the server as `key=value` pairs
        separated by semicolons.

        - returns: String dictionary of parsed cookies.
     */
    static internal func parseCookies(_ string: String) -> [String: String] {
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
