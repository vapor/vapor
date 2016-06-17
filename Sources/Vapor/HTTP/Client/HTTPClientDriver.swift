public protocol ClientDriver {
    func request(_ method: Method, url: String, headers: Headers, query: [String: String], body: HTTP.Body) throws -> HTTP.Response
}
