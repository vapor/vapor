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

    public init(method: Method = .get, path: String, host: String? = nil, body: Data = []) {
        self.init(method: method, uri: URI(path: path, host: host), headers: [:], body: body)
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
