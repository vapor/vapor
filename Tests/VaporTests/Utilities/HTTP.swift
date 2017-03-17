import HTTP
import URI

extension Request {
    convenience init(method: Method, path: String, host: String = "0.0.0.0") {
        let uri = URI(hostname: host, path: path)
        self.init(method: method, uri: uri)
    }
}

enum TestHTTPError: Error {
    case noBodyBytes
}

extension Response {
    func bodyString() throws -> String {
        guard let bytes = body.bytes else {
            throw TestHTTPError.noBodyBytes
        }

        return bytes.makeString()
    }
}

extension Responder {
    func responseBody(for method: Method, _ path: String) throws -> String {
        let request = Request(method: method, path: path)
        let response = try respond(to: request)
        return try response.bodyString()
    }

    func responseBody(for request: Request) throws -> String {
        let response = try respond(to: request)
        return try response.bodyString()
    }
}
