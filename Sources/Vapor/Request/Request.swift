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

    /**
        Create a new request with `Data`
    */
    public init(
        version: Version = Version(major: 1, minor: 1),
        method: Method = .get,
        path: String = "/",
        host: String? = nil,
        headers: Headers = [:],
        data: Data = []
    ) {
        self.init(method: method, uri: URI(path: path, host: host), version: version, headers: headers, body: .buffer(data))
    }

    public var contentType: String? {
        return headers["Content-Type"]
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
